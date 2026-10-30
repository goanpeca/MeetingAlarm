# Alarm Re-fire Loop Fix Plan (#8)

> **For agentic workers:** implement this plan task by task, in order. Steps use checkbox
> (`- [ ]`) syntax for tracking. Do not touch anything outside the files listed per task.
> Before writing code, climb the lean-code ladder (does it need to exist → already in the
> codebase → stdlib → platform → installed dep → a few lines → only then new code).

**Goal:** An alarm overlay that is already on screen is never torn down and re-presented or
replaced by a reschedule (calendar sync, wake, another alarm's dismiss or snooze), so the
dismiss puzzle and any typed answer survive until the user closes the overlay.

**Issue:** [goanpeca/MeetingAlarm#8](https://github.com/goanpeca/MeetingAlarm/issues/8)

**Branch:** `fix-alarm-issue-8-refire-loop` (cut from `origin/main` at `e9bf671`)

**Architecture:** The fire/schedule/wait decision moves into a pure function in `AlarmMath`
(pure core: unit-tested, counted by the coverage gate and mutation testing).
`OverlayController` gains one read-only property that reports whether an overlay is on screen;
it stays the single owner of that state. `AlarmScheduler` consults it and orders due alarms by
target time. Both are AppKit shells listed in `scripts/non-core-files.txt`.

**Spec:** `docs/design-docs/2026-08-26-meeting-alarm-design.md` §5 (AlarmScheduler and
OverlayController contracts, around line 201) and §17 (Snooze)

## Context

`AppCoordinator.sync()` runs at least every 30 s and ends in `reschedule()`
(`Sources/MeetingAlarm/AppCoordinator.swift:111`). `AlarmScheduler.reschedule` cancels every
timer and, for each armed alarm whose target is at or before `now`, calls `fire` immediately
(`Sources/MeetingAlarm/Alarm/AlarmScheduler.swift:50-51`). The only thing that stops an overdue
alarm from firing is the coordinator's `handled` filter (`AppCoordinator.swift:228`), which is
set only after a successful Dismiss (`AppCoordinator.swift:77-83`).

An alarm that is on screen but not yet dismissed is therefore "overdue and unhandled", and every
reschedule fires it again. `OverlayController.present` starts with `dismiss()` and builds new
windows (`Sources/MeetingAlarm/Alarm/OverlayController.swift:33`), and `ChallengeGateView` draws
its operands from `@State` random values (`Sources/MeetingAlarm/Alarm/ChallengeGateView.swift:11-12`),
so each re-presentation shows a new puzzle with an empty field and restarts the sound.

Observed on 2026-10-30 (unified log, subsystem `com.goanpeca.MeetingAlarm`): the same occurrence
fired at 08:55:01.265, 08:55:06.900 and 08:55:37.712; the last two each landed ~70 ms before a
`sync ok` line.

The same mechanism causes a second, related defect: when alarm B comes due while alarm A is on
screen, B replaces A; on the next reschedule A (still overdue, unhandled) replaces B, and the two
alternate on every sync. Because `reschedule` iterates a `Dictionary`, which alarm wins is
arbitrary.

## Outcome

- While an overlay is on screen, no reschedule re-presents it or replaces it.
- Other alarms that come due while an overlay is on screen wait, and are re-evaluated on the
  reschedule that follows the overlay closing. Every exit (Dismiss, Snooze, Join, Esc) goes
  through `OverlayController`'s `dismissAll` / `snooze` closures, which tear the windows down
  **before** calling the scheduler's callbacks, and both callbacks end in `reschedule()`.
- A waiting alarm is subject to the existing arming rules when it is re-evaluated (see D5):
  explicitly armed / armed-series alarms still fire until their meeting ends; auto-armed
  (derived) alarms are dropped once their meeting has started.
- When several alarms are due at once (launch, wake, after a close), the earliest target is
  presented first.
- With no overlay on screen, behaviour is otherwise unchanged: overdue unhandled alarms fire
  immediately (launch, wake, sync), future ones arm a timer.

## Global Constraints

- Swift 6 language mode; build must pass `swift build -Xswiftc -warnings-as-errors`.
- Files ≤ 250 lines; no `print` in `Sources/` (use `os.Logger` via `Log.make`).
- Imports point up only (`scripts/check-layers.sh`). `AlarmMath.swift` stays
  `import Foundation` only.
- **Esc always dismisses** the overlay; `OverlayKey` and `OverlayController`'s key monitor are not
  modified.
- Coverage gate ≥ 90% on the pure core (`scripts/coverage-gate.sh`); mutation floor 85%
  (`MUTATION_MIN`). New pure logic must be fully covered by tests that kill its mutants.
- No new source files are expected; if one is added it needs a row in
  `docs/generated/repo-map.md` (`make check-docs`).
- Commits: one line, < 72 chars, Conventional-Commit prefix, **no AI attribution**.
- `CHANGELOG.md` `[Unreleased]` is updated in the same change that alters behaviour.

## Decisions

**Chosen**

- **D1. One overlay at a time, gated on the overlay's own state.** `OverlayController` exposes
  `var isPresenting: Bool { !windows.isEmpty }` (read-only). The scheduler asks it instead of
  keeping a parallel flag, so the gate can never be left stuck by a path that closes or replaces
  an overlay without going through the scheduler (for example the Settings test alarm). An
  overlay that presented zero windows (no screens) does not block alarms.
- **D2. Pure decision function.** `AlarmMath.fireAction(target:now:isPresenting:) -> FireAction`
  with `enum FireAction: Equatable { case fireNow, schedule(after: TimeInterval), wait }`:
  - `target > now` → `.schedule(after: target - now)` (regardless of `isPresenting`; the timer
    re-checks at fire time).
  - `target <= now` and `!isPresenting` → `.fireNow`.
  - `target <= now` and `isPresenting` → `.wait`.
- **D3. Timer fires also respect the gate.** `fire(id:config:profile:)` returns without
  presenting when `overlay.isPresenting`, and logs it. The alarm is then overdue and is
  re-evaluated by the reschedule that runs when the current overlay closes.
- **D4. Earliest target first.** `reschedule` iterates armed alarms sorted by target time, so
  the first `.fireNow` is the earliest-due alarm, and every later due alarm sees
  `isPresenting == true` and gets `.wait`.
- **D5. Waiting alarms follow the existing arming rules (accepted limitation).** A derived
  (auto-arm) alarm whose meeting starts while it waits is dropped by
  `AppCoordinator+Scheduling.swift:27-28`, and any alarm whose meeting ends while it waits is
  dropped by `AlarmScheduler.swift:43`. This matches the existing rule that auto-arm never
  full-screens a meeting already in progress. No queue that outlives those rules is added.

**Rejected**

- *A scheduler-side `presentingId` flag* — duplicates state owned by `OverlayController`; any
  close/replace path that bypasses the scheduler's closures leaves it set and silently blocks
  every later alarm until relaunch.
- *Mark an alarm `handled` at fire time and un-handle on snooze* — changes the meaning of
  `handled` (also used for history and by `Store+Arming.swift` / `Store+Series.swift`) and widens
  the blast radius.
- *Skip only the on-screen alarm, still let other overdue alarms preempt it* — leaves the A/B
  alternation described in Context.
- *Stop calling `reschedule()` from `sync()`* — sync must keep re-timing edited events and arming
  newly visible ones.
- *Seed the puzzle deterministically so a re-present looks the same* — hides the symptom; the
  sound restart, window rebuild and lost input remain.

## Out of scope

- [goanpeca/MeetingAlarm#9](https://github.com/goanpeca/MeetingAlarm/issues/9) (snooze handling).
- Changing the Settings **Test alarm** (`AppCoordinator.testAlarm`). With D1 a real alarm that
  comes due while a test overlay is open now waits instead of replacing it; no code change there.
- Any change to `handled`, `Store`, `activeArmedConfigs`, `OverlayView`, `ChallengeGateView`,
  `OverlayKey`, or the sync interval. `OverlayController` changes only by the one read-only
  property in D1.

## Gotchas

- `OverlayController`'s `dismissAll` and `snooze` closures (`OverlayController.swift:35-42`)
  call `self?.dismiss()` **before** the scheduler's `onDismiss` / `onSnooze`. That ordering is
  what makes `isPresenting` false by the time the coordinator's `reschedule()` runs. Do not
  reorder them.
- `reschedule` calls `cancelAll()` first; that is unchanged.
- `AlarmScheduler.swift` and `OverlayController.swift` are excluded from coverage and mutation.
  Only `AlarmMath.fireAction` is unit-tested; the gate wiring, the ordering (D4), and the
  closure ordering are covered by the manual checks M1–M7 only. Do not claim otherwise in the PR.
- The red step for T1 is a compile error (the function does not exist yet), not a failing
  assertion.
- Local builds with only the Command Line Tools (Swift 6.4 / macOS 27 SDK) fail on SwiftUI
  `@State` macros. Build locally with
  `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk` (for example
  `SDKROOT=… make ci`). CI uses Xcode 26 and needs no workaround.

## Files that change

- Modify: `Sources/MeetingAlarm/Alarm/AlarmMath.swift` — add `FireAction` and `fireAction`.
- Modify: `Tests/MeetingAlarmTests/AlarmMathTests.swift` — tests for `fireAction`.
- Modify: `Sources/MeetingAlarm/Alarm/OverlayController.swift` — read-only `isPresenting`.
- Modify: `Sources/MeetingAlarm/Alarm/AlarmScheduler.swift` — sort by target, use `fireAction`,
  gate in `fire`, log waits.
- Modify: `docs/design-docs/2026-08-26-meeting-alarm-design.md` — one bullet in §17.
- Modify: `CHANGELOG.md` — `[Unreleased]` → `### Fixed` entry.

## Task breakdown

```
T1 — Pure decision: FireAction + AlarmMath.fireAction, with tests
     files:   Sources/MeetingAlarm/Alarm/AlarmMath.swift,
              Tests/MeetingAlarmTests/AlarmMathTests.swift
     depends: [independent]
     verify:  swift test --filter AlarmMath → 6 tests pass (new tests fail to compile before T1)

T2 — OverlayController.isPresenting (read-only)
     files:   Sources/MeetingAlarm/Alarm/OverlayController.swift
     depends: [independent]
     verify:  swift build -Xswiftc -warnings-as-errors → OK

T3 — Scheduler: sort by target, route through fireAction, gate fire(), log waits
     files:   Sources/MeetingAlarm/Alarm/AlarmScheduler.swift
     depends: [depends on: T1, T2]
     verify:  swift build -Xswiftc -warnings-as-errors && make scan → OK; manual M1–M7

T4 — Docs + changelog
     files:   docs/design-docs/2026-08-26-meeting-alarm-design.md, CHANGELOG.md
     depends: [independent]
     verify:  make check-links → OK
```

```
Wave 1 → T1, T2, T4   (independent)
Wave 2 → T3           (after T1, T2)
```

---

## Task 1: Pure decision function

**Files:**
- Modify: `Sources/MeetingAlarm/Alarm/AlarmMath.swift`
- Test: `Tests/MeetingAlarmTests/AlarmMathTests.swift`

**Interfaces:**
- Produces: `enum FireAction: Equatable, Sendable { case fireNow; case schedule(after: TimeInterval); case wait }`
- Produces: `static func AlarmMath.fireAction(target: Date, now: Date, isPresenting: Bool) -> FireAction`

- [ ] **Step 1: Write the failing tests** (append to `AlarmMathTests`, reusing its `start` fixture)

```swift
    @Test("fireAction schedules a future target, whether or not an overlay is up")
    func fireActionFuture() {
        let target = start.addingTimeInterval(90)
        #expect(AlarmMath.fireAction(target: target, now: start, isPresenting: false)
            == .schedule(after: 90))
        #expect(AlarmMath.fireAction(target: target, now: start, isPresenting: true)
            == .schedule(after: 90))
    }

    @Test("fireAction fires a due or overdue target when nothing is on screen")
    func fireActionDue() {
        #expect(AlarmMath.fireAction(target: start, now: start, isPresenting: false) == .fireNow)
        #expect(AlarmMath.fireAction(
            target: start.addingTimeInterval(-60), now: start, isPresenting: false
        ) == .fireNow)
    }

    @Test("fireAction waits on a due or overdue target while an overlay is on screen")
    func fireActionWaits() {
        #expect(AlarmMath.fireAction(target: start, now: start, isPresenting: true) == .wait)
        #expect(AlarmMath.fireAction(
            target: start.addingTimeInterval(-60), now: start, isPresenting: true
        ) == .wait)
    }
```

- [ ] **Step 2: Run and confirm red**

Run: `swift test --filter AlarmMath`
Expected: compile error — `fireAction` / `FireAction` not found.

- [ ] **Step 3: Implement** (in `AlarmMath.swift`)

```swift
/// What the scheduler should do with one alarm right now.
enum FireAction: Equatable, Sendable {
    case fireNow
    case schedule(after: TimeInterval)
    /// Due, but an overlay is on screen; re-evaluated on the reschedule after it closes.
    case wait
}

// inside enum AlarmMath:
    /// Decide whether an alarm fires now, arms a timer, or waits. Only one overlay is shown at
    /// a time, so a due alarm never replaces (or re-presents) the one on screen.
    static func fireAction(target: Date, now: Date, isPresenting: Bool) -> FireAction {
        if target > now {
            return .schedule(after: target.timeIntervalSince(now))
        }
        return isPresenting ? .wait : .fireNow
    }
```

- [ ] **Step 4: Run and confirm green**

Run: `swift test --filter AlarmMath`
Expected: all `AlarmMath` tests pass (3 existing + 3 new).

- [ ] **Step 5: Commit**

```bash
git add Sources/MeetingAlarm/Alarm/AlarmMath.swift Tests/MeetingAlarmTests/AlarmMathTests.swift
git commit -m "feat: add pure fire/schedule/wait decision to AlarmMath"
```

---

## Task 2: OverlayController.isPresenting

**Files:**
- Modify: `Sources/MeetingAlarm/Alarm/OverlayController.swift`

**Interfaces:**
- Produces: `var isPresenting: Bool` (read-only, `@MainActor` via the class).

- [ ] **Step 1: Implement** (below the stored properties)

```swift
    /// Whether an alarm overlay is currently on screen.
    var isPresenting: Bool {
        !windows.isEmpty
    }
```

- [ ] **Step 2: Verify**

Run: `swift build -Xswiftc -warnings-as-errors`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/MeetingAlarm/Alarm/OverlayController.swift
git commit -m "feat: expose whether an alarm overlay is on screen"
```

---

## Task 3: Scheduler gate

**Files:**
- Modify: `Sources/MeetingAlarm/Alarm/AlarmScheduler.swift`

**Interfaces:**
- Consumes: `AlarmMath.fireAction`, `FireAction` (T1); `OverlayController.isPresenting` (T2).
- No API change for `AppCoordinator`.

- [ ] **Step 1: Rewrite `reschedule`** — compute each target first, iterate earliest-first, and
  route through `fireAction`:

```swift
    /// Cancel all timers and re-arm from the current armed set + snoozes. Due alarms present
    /// earliest-first, one at a time; the rest wait for the reschedule after it closes.
    func reschedule(armed: [String: ArmedConfig], snoozes: [String: Date], now: Date) {
        cancelAll()
        let pending = armed.compactMap { id, config -> (String, ArmedConfig, SensoryProfile, Date)? in
            guard config.meeting.end > now else { return nil } // meeting already over
            let profile = resolveProfile(config)
            let target = snoozes[id]
                ?? AlarmMath.fireTime(meetingStart: config.meeting.start, leadTime: profile.leadTime)
            return (id, config, profile, target)
        }
        for (id, config, profile, target) in pending.sorted(by: { $0.3 < $1.3 }) {
            switch AlarmMath.fireAction(target: target, now: now, isPresenting: overlay.isPresenting) {
            case .fireNow:
                fire(id: id, config: config, profile: profile)
            case let .schedule(after: delay):
                tasks[id] = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                    self?.fire(id: id, config: config, profile: profile)
                }
            case .wait:
                log.info("alarm \(id, privacy: .public) waiting: another alarm is on screen")
            }
        }
    }
```

If SwiftLint flags the tuple (`large_tuple`), replace it with a small `private struct Pending`
in the same file; do not disable the rule.

- [ ] **Step 2: Gate `fire`** — at the top of `fire(id:config:profile:)`:

```swift
        guard !overlay.isPresenting else {
            log.info("alarm \(id, privacy: .public) waiting: another alarm is on screen")
            return
        }
```

The `onSnooze` / `onDismiss` closures passed to `overlay.present` are unchanged.

- [ ] **Step 3: Verify build + lint**

Run: `swift build -Xswiftc -warnings-as-errors && make scan`
Expected: build succeeds; scan reports no violations.

- [ ] **Step 4: Manual verification** (shell code; not unit-testable)

Setup: `make app && open MeetingAlarm.app`; Settings → Dismiss challenge = Math; lead time
5 min. Log command used below:
`log show --last 10m --info --predicate 'subsystem == "com.goanpeca.MeetingAlarm"'`.

- **M1 (the bug):** arm an event starting ~6 min from now. When the overlay appears, wait
  ≥ 70 s (two syncs) without typing. Expected: the puzzle operands do not change, the sound does
  not restart, and the log shows exactly one `firing alarm for <id>` line for that occurrence.
- **M2 (dismiss is final):** solve the puzzle. Expected: the overlay closes and does not return
  on the next sync.
- **M3 (queued second alarm, explicit arm):** explicitly arm A and B starting 1 min apart; leave
  A's overlay open past B's fire time. Expected: zero or more `waiting` lines for B and no
  `firing` line for B while A is up; after dismissing A, exactly one `firing alarm for <B>` line
  and B presents immediately.
- **M4 (Esc):** with an overlay up, press Esc. Expected: the overlay closes immediately.
- **M5 (snooze releases the queue):** repeat M3 but press Snooze on A. Expected: B presents
  immediately; A re-fires at its snooze target after B is closed.
- **M6 (wake):** with A on screen, sleep the Mac ≥ 1 min and wake it. Expected: A is still the
  overlay shown and no new `firing` line appears for A.
- **M7 (derived alarm dropped, D5):** with Settings → Auto-arm on, leave an explicit alarm A on
  screen past the **start** of an auto-armed meeting B. Expected: after closing A, B does not
  fire (its meeting has started); this is the accepted D5 behaviour.

- [ ] **Step 5: Commit**

```bash
git add Sources/MeetingAlarm/Alarm/AlarmScheduler.swift
git commit -m "fix: never re-present or preempt an on-screen alarm"
```

---

## Task 4: Docs + changelog

**Files:**
- Modify: `docs/design-docs/2026-08-26-meeting-alarm-design.md` (§17 Snooze, after the
  **Behavior** bullet)
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Design doc** — add a bullet to §17:

```markdown
- **One overlay at a time:** while an alarm is on screen, rescheduling (sync, wake, another
  alarm's snooze or dismiss) never re-presents or replaces it. Other alarms that come due wait
  and are re-evaluated, earliest first, when the overlay closes; a waiting auto-armed alarm is
  dropped once its meeting has started, and any alarm is dropped once its meeting has ended.
```

- [ ] **Step 2: Changelog** — under `## [Unreleased]`, add (create the heading if absent):

```markdown
### Fixed

- An alarm left on screen is no longer re-presented on every calendar sync, which reset the
  dismiss puzzle and restarted the sound. Alarms that come due meanwhile wait until it closes,
  earliest first (#8).
```

- [ ] **Step 3: Verify**

Run: `make check-links`
Expected: OK.

- [ ] **Step 4: Commit**

```bash
git add docs/design-docs/2026-08-26-meeting-alarm-design.md CHANGELOG.md
git commit -m "docs: record one-overlay-at-a-time scheduling rule"
```

---

## Proof

| Requirement | Evidence | Kind |
|---|---|---|
| Decision rule: due + on screen → wait | `fireActionWaits` | unit |
| Decision rule: due + nothing on screen → fire | `fireActionDue` | unit |
| Decision rule: future → timer | `fireActionFuture` | unit |
| On-screen alarm not re-presented by sync | M1 | manual |
| Dismiss still final | M2 | manual |
| Queued alarm fires after close / snooze | M3, M5 | manual |
| Wake does not re-present | M6 | manual |
| D5 limitation behaves as documented | M7 | manual |
| Esc always dismisses | M4; `OverlayKeyTests` unchanged and green | manual + unit |
| Gates | `make ci` green | CI |

The scheduler wiring (D1, D3, D4) lives in files excluded from coverage and mutation, so only
the manual checks cover it.

## Verification (bottom line)

Run: `make ci` (locally prefix `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk`
when only the Command Line Tools are installed).
Expected: every step green; the `AlarmMath` suite shows 6 passing tests; coverage gate ≥ 90%.
Then M1–M7 pass on a locally built `MeetingAlarm.app`.

## Progress

- 2026-10-30 — Plan written; branch cut from `origin/main` (`e9bf671`). Not yet implemented.
- 2026-10-30 — Plan red-teamed (APPROVE WITH CHANGES); folded in: gate on
  `OverlayController.isPresenting` instead of a scheduler flag, earliest-first ordering, D5
  documented, wait logging, manual checks M5–M7, §5 citation.

## Decision log

- 2026-10-30 — Chose a "one overlay at a time" gate over marking alarms handled at fire time;
  see Decisions → Rejected.
- 2026-10-30 — Switched the gate from a scheduler-owned `presentingId` to
  `OverlayController.isPresenting` so it cannot be left stuck by a close path that bypasses the
  scheduler.
- 2026-10-30 — Accepted D5: waiting alarms follow the existing arming rules rather than a
  persistent queue.
