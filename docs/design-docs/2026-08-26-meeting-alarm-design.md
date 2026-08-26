# meeting-alarm — Design Spec

**Date:** 2026-08-26
**Status:** Draft for review
**Verification:** current
**Platform:** macOS 14+ (developed on macOS 26 / Xcode 26 / Swift 6.3, Apple Silicon)

---

## 1. Purpose

A menu-bar macOS app that makes it **impossible to miss a meeting while you're at the
computer**. It reads your calendar, lets you **arm an extra alarm per meeting**, and at the
chosen moment throws a **full-screen colored overlay across every display** with an optional
sound. The alert is driven by a configurable **sensory profile** with two presets — a
high-intensity **Blast** and a predictable, sensory-safe **Gentle Ramp**.

The Gentle Ramp preset is a first-class design goal, not an afterthought: it answers the
question "how should this work for someone who is autistic (or has ADHD / sensory
sensitivities / gets stuck in hyperfocus)?" — see §9.

## 2. Goals / Non-goals

### Goals
- Read upcoming meetings from **both** the macOS Calendar (EventKit) **and** Google
  Calendar directly (OAuth), switchable behind one interface.
- Per-meeting arming: choose which meetings get an extra alarm, and which preset.
- A full-screen, multi-display overlay that is loud/red when you want it and calm/gradual
  when you want it.
- Optional sound, fully user-controllable (off / volume / which sound).
- Run quietly in the menu bar, survive sleep/wake, and never trap the user.
- **Be a well-engineered, agent-navigable repo**: enforced structure, linting, formatting,
  meaningful test coverage, and CI (see §10–§13).

### Non-goals (v1 — YAGNI)
- Creating or editing calendar events.
- Notification Center integration, Focus modes, or Shortcuts actions.
- iOS / iPadOS.
- Settings sync across machines.
- Managing multiple Google accounts at once (one active account per source).
- Notarized/distributable build (local ad-hoc signing only; distribution is future work).
- Complex snooze scheduling (a single "dismiss" is v1; snooze is noted as future).

## 3. Repository organization (harness engineering)

Structured per OpenAI's *harness engineering* approach: the **repository is the system of
record**, `AGENTS.md` is a short **navigation map** (~100 lines, progressive disclosure — not
an encyclopedia), and `docs/` holds the durable knowledge, catalogued and status-tracked so a
human *or* an agent can reason about the codebase and can't drift from its rules by accident.

```
meeting-alarm/
├── AGENTS.md                        # ~100-line navigation map / table of contents
├── README.md                        # human quickstart: Google + permission setup
├── Makefile                         # build · app · test · coverage · lint · format · scan
├── Package.swift                    # SwiftPM executable target (opens directly in Xcode 26)
├── .swiftlint.yml                   # lint rules incl. custom (file size, naming)
├── .swiftformat                     # deterministic formatting config
├── .github/workflows/
│   ├── ci.yml                       # build + test + coverage gate + format-lint + layer check
│   └── quality-scan.yml             # scheduled drift scan (harness "recurring task" analog)
├── Resources/Info.plist             # LSUIElement, calendar usage strings
├── scripts/
│   ├── make_app.sh                  # assemble + ad-hoc-sign MeetingAlarm.app → open
│   ├── check-layers.sh              # custom linter: enforce import direction (repair hints)
│   └── coverage-gate.sh             # parse llvm-cov; fail below threshold
├── docs/
│   ├── architecture/
│   │   └── overview.md              # domain map + layer ordering + allowed import directions
│   ├── design-docs/
│   │   ├── INDEX.md                 # catalog with verification status (current/stale/superseded)
│   │   └── 2026-08-26-meeting-alarm-design.md   # ← this document
│   ├── execution-plans/             # implementation plan(s) + progress logs (from writing-plans)
│   ├── technical-debt/
│   │   └── README.md                # known issues, categorized by domain/layer
│   ├── principles/
│   │   └── golden-principles.md     # golden principles / core beliefs as mechanical rules
│   └── quality/
│       └── quality.md               # grades each domain/layer; gaps tracked over time
├── Sources/MeetingAlarm/            # layered source (see §5); imports only point "up"
└── Tests/MeetingAlarmTests/         # Swift Testing unit tests for the pure-logic core
```

### Layering (enforced)
Strict bottom-up layer ordering; **imports may only point upward** — a lower layer never
imports a higher one. Violations are caught by `scripts/check-layers.sh` (and documented in
`docs/architecture/overview.md`), whose error messages tell you exactly how to fix them.

```
Models        (Meeting, SensoryProfile)                 — pure; imports no app-local layer
   ▲
State         (Store, Keychain)                          — may import Models
   ▲
Services      (Calendar/*, Alarm/*, SoundPlayer)         — may import Models, State
   ▲
Runtime/UI    (App, UI/*)                                — may import everything below
```

### Golden principles (`docs/principles/golden-principles.md`)
Subjective taste encoded as mechanical, checkable rules, e.g.:
- **Files ≤ ~250 lines.** Outgrowing it means the file does too much — split it.
- **Pure logic stays pure.** Fire-time math, presets, JSON→model mapping, and OAuth
  PKCE/URL construction live in functions with **no** AppKit/EventKit/URLSession import, so
  they are unit-testable without network or UI.
- **Imports point up only** (the layer rule above).
- **One structured logger per subsystem** via `os.Logger`; `print` is banned in `Sources/`.
- **Secrets only in Keychain** — never `UserDefaults`, never logs.
- **Every source file maps to exactly one layer directory.**
- **Safety invariant:** the overlay is always dismissible with Esc.

Each rule is enforced by SwiftLint, `check-layers.sh`, or a test — not left to good intentions.

### Quality doc & recurring scan
`docs/quality/quality.md` grades each domain/layer (Models, State, Calendar, Alarm, UI) on
consistency + coverage, tracking gaps over time. `.github/workflows/quality-scan.yml` runs
`scripts/*` on a schedule to flag drift (oversized files, layer violations, `print` usage,
missing tests) — the local analog of OpenAI's recurring background refactor task. (It can also
be driven from a Claude Code `/loop` or scheduled agent.)

## 4. Data flow

1. **App launch** → `Store` loads settings + armed set; `App` selects the active
   `CalendarSource` (EventKit or Google) from settings.
2. **Sync** → active source `fetchUpcoming(next 24h)` returns `[Meeting]`. `MenuContentView`
   lists them; armed meetings are checked. A repeating sync (default every 5 min) refreshes.
3. **Arming** → toggling a meeting writes its key + chosen preset into `Store`, then asks
   `AlarmScheduler` to (re)compute.
4. **Scheduling** → for each armed meeting, `AlarmScheduler` computes `fireTime`
   (`start − leadTime` for Gentle Ramp, `start` for Blast) and arms a timer. On wake or
   re-sync it recomputes; a fire time already passed (but meeting not yet ended) fires
   immediately.
5. **Firing** → at `fireTime`, `AlarmScheduler` tells `OverlayController` to present with the
   meeting's `SensoryProfile`; `SoundPlayer` plays if enabled. The overlay ramps per the
   profile and shows a live countdown to `start`.
6. **Dismissal** → **Esc always dismisses** (safety), plus the profile's configured dismissal
   (click / key / auto-after-N). Overlay tears down all per-screen windows.

## 5. Components (unit contracts)

Each unit lists **what it does / interface / depends on**, and its layer.

### Meeting — `Models/Meeting.swift` · layer: Models
- **What:** immutable value describing one meeting occurrence.
- **Interface:** `struct Meeting { let id: String; let title: String; let start: Date; let end: Date; let sourceKind: SourceKind }`. `id` is stable per occurrence (EventKit: `eventIdentifier` + occurrence start; Google: event `id` + start).
- **Depends on:** nothing (pure).

### SensoryProfile — `Models/SensoryProfile.swift` · layer: Models
- **What:** the alarm's tunable behavior + named presets.
- **Interface:** knobs — `color`, `peakOpacity` (0…1), `leadTime` (seconds before start), `escalation` (`.instant` / `.easeIn`), `pulse` (Bool), `sound` (`SoundChoice?`), `volume` (0…1), `dismissal` (`.clickAnywhere` / `.keyPress` / `.auto(after:)`), `showCountdown` (Bool). Statics: `.blast`, `.gentleRamp`. `Codable` for persistence.
- **Depends on:** nothing (pure). Directly unit-tested.

### CalendarSource — `Calendar/CalendarSource.swift` · layer: Services
- **What:** the seam that hides *which* calendar backend is active.
- **Interface:** `protocol CalendarSource { var kind: SourceKind { get }; func authorize() async throws; func fetchUpcoming(within: DateInterval) async throws -> [Meeting] }`.
- **Depends on:** `Meeting`.

### EventKitSource — `Calendar/EventKitSource.swift` · layer: Services
- **What:** reads timed events from the macOS Calendar database — which already aggregates Google, iCloud, Exchange, etc. once the account is added in System Settings → Internet Accounts.
- **Interface:** implements `CalendarSource`. `authorize()` → `EKEventStore.requestFullAccessToEvents`. `fetchUpcoming` → `predicateForEvents(withStart:end:calendars:)`, filter to non-all-day events, map to `Meeting`.
- **Depends on:** `EventKit`, `Meeting`. Requires `NSCalendarsFullAccessUsageDescription` (+ legacy `NSCalendarsUsageDescription`) in Info.plist and a proper app bundle.

### GoogleCalendarSource — `Calendar/GoogleCalendarSource.swift` · layer: Services
- **What:** reads events straight from Google, independent of macOS Calendar.
- **Interface:** implements `CalendarSource`. Uses `GoogleAuth` for a bearer token, then `GET https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=…&timeMax=…&singleEvents=true&orderBy=startTime`; decodes JSON → `[Meeting]`. Pure decode helper (`Meeting(fromGoogleJSON:)`) is unit-tested.
- **Depends on:** `GoogleAuth`, `URLSession`, `Meeting`. Scope: `calendar.events.readonly`.

### GoogleAuth — `Calendar/GoogleAuth.swift` · layer: Services
- **What:** OAuth 2.0 for a desktop app using the **loopback redirect + PKCE** flow (Google's current recommendation for native apps; OOB is deprecated).
- **Interface:** `func signIn() async throws` (opens the system browser to the consent URL, runs a tiny `127.0.0.1:<ephemeral>` listener to catch the `code`, exchanges it with the PKCE `code_verifier`), `func accessToken() async throws -> String` (cached or refreshed). Pure helpers `makeAuthURL`, `makePKCE`, `parseTokenResponse` are extracted for unit tests.
- **Depends on:** `URLSession`, a minimal loopback listener (`Network.NWListener`), `Keychain`. Client ID + client secret (from the user's downloaded OAuth JSON — for installed apps the "secret" is not truly confidential) and refresh token live in Keychain.

### AlarmScheduler — `Alarm/AlarmScheduler.swift` · layer: Services
- **What:** owns which meetings are armed and fires them at the right time.
- **Interface:** `arm(_ meetings: [ArmedMeeting])`, `fireTime(for:profile:now:) -> Date` (pure, unit-tested), internal timers via `DispatchSourceTimer`. Observes `NSWorkspace.didWakeNotification` to recompute. Fires immediately for a fire time that elapsed during sleep if the meeting hasn't ended.
- **Depends on:** `OverlayController`, `SoundPlayer`, `Store`, `Meeting`.

### OverlayController — `Alarm/OverlayController.swift` · layer: Services (`@MainActor`)
- **What:** the visible alarm — a borderless window on **every** `NSScreen`.
- **Interface:** `present(profile:meeting:)`, `dismiss()`. Each window: `.borderless`, `level` at screen-saver/maximum, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` so it covers other apps and Spaces; colored background animating `alphaValue` 0→`peakOpacity` over `leadTime` (`.easeIn`) or immediately (`.instant`); optional pulse; centered live countdown label. **Esc always dismisses.** Honors system **Reduce Motion** (no pulse/animation → stepped or steady).
- **Depends on:** `AppKit`, `SensoryProfile`, `Meeting`.

### SoundPlayer — `Alarm/SoundPlayer.swift` · layer: Services
- **What:** optional audio for an alarm.
- **Interface:** `play(_ choice:volume:repeat:)`, `stop()`. No-op when the profile has no sound.
- **Depends on:** `AppKit` (`NSSound`).

### Store — `State/Store.swift` · layer: State
- **What:** persists armed meetings + all settings.
- **Interface:** `ObservableObject`; `armed: [String: ArmedConfig]`, `defaultPreset`, `activeSource`, `syncInterval`, plus profile overrides. Backed by `UserDefaults` (`Codable`). Round-trip unit-tested.
- **Depends on:** `Foundation`, `Models`.

### Keychain — `State/Keychain.swift` · layer: State
- **What:** minimal `kSecClassGenericPassword` get/set/delete for Google tokens + creds.
- **Interface:** `set(_:for:)`, `get(_:) -> Data?`, `delete(_:)`.
- **Depends on:** `Security`.

### UI — `UI/MenuContentView.swift`, `UI/SettingsView.swift` · layer: Runtime/UI (`@MainActor`)
- **What:** the menu-bar popover (meeting list with a toggle + preset picker per row, a
  permission/error banner, and a **Test Alarm** button) and a settings pane (source picker,
  Google **Sign in** button + client-ID/secret fields, default preset, per-knob controls).
- **Depends on:** `Store`, active `CalendarSource`, `AlarmScheduler`, `OverlayController`.

## 6. Scheduling & lifecycle details

- **Sync cadence:** default 5 min; also on launch, on wake, and right after arming/disarming.
- **Timers:** `DispatchSourceTimer` per armed meeting (not one polling loop), recomputed on
  each sync so calendar edits (time change / cancellation) are respected.
- **Sleep/wake:** on `didWakeNotification`, recompute all fire times; fire overdue-but-not-ended
  meetings immediately.
- **Window edge cases:** recurring events expanded via `singleEvents`/EventKit occurrences;
  all-day events excluded from the "meetings" list; meetings already started at launch are
  shown but only fire if their fire time is still in the future (or immediately per the
  overdue rule).

## 7. Persistence & identity

- **Armed state** keyed by `Meeting.id` (occurrence-stable) → `{ presetName or custom profile }`,
  in `UserDefaults`.
- **Settings** (active source, default preset, knob values, sync interval) in `UserDefaults`.
- **Secrets** (Google client id/secret, refresh token) in **Keychain**, never in `UserDefaults`
  or logs.

## 8. Error handling

- **No calendar permission:** menu shows a clear banner + a button that opens the Calendar
  privacy pane in System Settings. No silent failure.
- **Google not configured / refresh fails:** menu prompts re-sign-in; the app keeps working
  on last-known meetings; errors are surfaced, never swallowed.
- **Fetch failure:** keep last-known meetings, show a subtle error state, retry on next sync.
- **Overlay safety:** the overlay can *never* trap the user — **Esc always dismisses**, even
  in Blast, and dismissal always tears down every per-screen window.

## 9. Accessibility & the "if I were autistic" design

The default framing of "flash the screen red and blast a sound" is a **high-intensity sensory
interrupt**. For many autistic people (and people with ADHD, migraine/photosensitivity, or
sensory processing differences) that specific design can cause distress or a startle response —
while the *underlying* need (not losing track of time, being pulled out of hyperfocus) is often
stronger, not weaker. So the app treats intensity as a **user-owned knob**, and ships a second
preset built on these principles:

- **Predictability over surprise:** the **Gentle Ramp** preset appears ~5 minutes early and
  grows on a known, monotonic curve. A **live countdown** is always visible, so the alert is
  never a shock — you can see it coming.
- **Advance warning to ease transitions / break hyperfocus:** the early, gradual onset gives
  time to reach a stopping point instead of being yanked out of a task.
- **Sensory control:** color, peak intensity, sound (fully optional), and volume are all
  adjustable. Nothing is fixed at "maximum."
- **No strobe by default; honor Reduce Motion:** pulsing is off in Gentle Ramp, and when the
  system **Reduce Motion** setting is on, the overlay never animates/flashes — it steps or
  holds steady. This avoids photosensitive triggers.
- **A guaranteed safe exit:** Esc always dismisses, so the user is never trapped by the alert.

**Blast** remains available unchanged for when a blunt, can't-miss interrupt is exactly what's
wanted. Both live on the same engine and the user chooses per meeting.

## 10. Code quality & tooling (Swift best practices)

- **Formatting:** [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) with a checked-in
  `.swiftformat`. CI runs `swiftformat --lint` (fails on drift); `make format` fixes locally.
- **Linting:** [SwiftLint](https://github.com/realm/SwiftLint) with `.swiftlint.yml`, including
  opt-in rules and **custom rules** (banned `print`, file-length limit). `make lint` locally;
  CI enforces.
- **Layer/import enforcement:** `scripts/check-layers.sh` fails the build on an upward-only
  violation, printing the offending file, the illegal import, and the fix.
- **Strict concurrency:** `swiftLanguageMode(.v6)`, `.unsafeFlags(["-warnings-as-errors"])` in
  CI, `Sendable`/`@MainActor` applied deliberately (UI + overlay are `@MainActor`).
- **Structured logging:** a single `os.Logger` per subsystem (`subsystem: "com.goanpeca.MeetingAlarm"`,
  `category:` per component). No `print` in `Sources/`.
- **Docs:** public types carry doc comments (`///`); `AGENTS.md` + `docs/` are the map.

## 11. Build, packaging & verification

- **Bundle identifier:** `com.goanpeca.MeetingAlarm` (matches the `os.Logger` subsystem).
- **Build:** `swift build` produces the binary; `scripts/make_app.sh` assembles
  `MeetingAlarm.app` (`Contents/MacOS`, `Contents/Info.plist`, `Contents/Resources`),
  **ad-hoc code-signs** it (`codesign --force --deep --sign -`) so EventKit/TCC prompts work,
  and `open`s it. Fully command-line; `Package.swift` also opens directly in Xcode 26.
- **`Makefile` targets:** `build`, `app`, `run`, `test`, `coverage`, `lint`, `format`,
  `check-layers`, `scan`, `clean`.
- **Verification during build:**
  1. `swift build` compiles clean (warnings-as-errors); `swift test` passes; coverage gate passes.
  2. `MeetingAlarm.app` launches; the menu-bar item appears (no dock icon).
  3. **Test Alarm** renders the overlay across the display(s) with sound, and Esc dismisses.
  4. Arming a meeting persists across relaunch.
  5. EventKit list populates after the permission grant. (Google path verified once the user
     supplies OAuth credentials — see §12.)

## 12. What the user must provide

1. **EventKit path:** ensure the Google account is added in **System Settings → Internet
   Accounts**, and click **Allow** on the Calendar permission prompt at first launch. No
   credentials needed.
2. **Direct-Google path:** create a Google Cloud project → OAuth consent screen (External, add
   yourself as a test user) → **OAuth client ID of type "Desktop app"** → paste the client ID +
   secret into Settings. The README documents each click. Scope requested:
   `calendar.events.readonly`. Until this is provided, EventKit is the default and the app is
   fully functional through it.

## 13. Testing strategy & coverage

- **Framework:** **Swift Testing** (`import Testing`, native to Swift 6.3 / Xcode 26).
- **Unit (no network / no UI):** `SensoryProfile` preset values; `AlarmScheduler.fireTime`
  math across Blast/Gentle and edge times (overdue, all-day excluded, wake); `Store` codable
  round-trip; EventKit + Google JSON → `Meeting` mapping; `GoogleAuth` PKCE + auth-URL + token
  parsing.
- **Coverage gate:** `swift test --enable-code-coverage`; `scripts/coverage-gate.sh` parses
  `llvm-cov export` and **fails CI below the threshold**. Start at **70%** measured against the
  pure-logic core (Models + the pure functions in Services); thin AppKit/EventKit/URLSession
  shells are excluded from the denominator and covered by the manual checklist below. The
  threshold is recorded in `docs/quality/quality.md` and ratcheted upward over time.
- **Manual / integration:** EventKit read after permission; the Test-Alarm overlay across one
  and multiple displays; Esc-dismiss safety; the Google sign-in flow once credentials exist.

## 14. Security & privacy

- Read-only calendar scopes; the app never writes to a calendar.
- Google tokens + client secret live only in the **Keychain**; never logged or written to
  `UserDefaults`.
- No telemetry, no network calls except Google's OAuth/Calendar endpoints (only when the
  Google source is active). Calendar data stays on-device.
- Ad-hoc signing is for local use; distribution would require an Apple Developer ID +
  notarization (out of scope for v1).

## 15. Open questions / future

- **Snooze:** a simple "remind me again in 1 min" on dismiss — deferred to keep v1 lean.
- **Login item:** auto-launch at login via `SMAppService` — easy to add later; default off.
- **Per-calendar filtering:** choose which sub-calendars are eligible — future.
- **Notarized distribution:** if this ever leaves your machine.
- **CI runner:** GitHub Actions `macos-14`+ image; SwiftFormat/SwiftLint installed via Homebrew
  in the workflow (kept out of the build graph so builds stay fast).
