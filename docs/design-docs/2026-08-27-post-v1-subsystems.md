# Design — Post-v1 Subsystems

Design record for the subsystems added after the [v1 spec](2026-08-26-meeting-alarm-design.md).
Contracts and rationale; the exhaustive file list is the [module map](../generated/repo-map.md).

## 1. Recurring-series arming

**Goal.** Opt a whole repeating meeting out (or back in), not just one day, with a per-action
"this event vs. the whole series" choice (mirroring macOS Calendar).

**Design.**
- `Meeting.seriesId` identifies a series across occurrences — EventKit: the shared event
  identifier (`hasRecurrenceRules`). `nil` = one-off.
- Meetings are armed by default. `Store.excludedSeriesIds` records whole-series opt-outs and
  `excludedMeetingIds` records one-off opt-outs; an explicit arm can re-enable a single
  occurrence in an otherwise excluded series. Legacy explicit series rules retain their
  per-occurrence skips (`seriesExceptions`).
- `SeriesMaterializer` (pure, tested) decides which legacy explicit-series occurrences to
  schedule. The coordinator fetches a rolling **60-day horizon** on every sync, derives the
  default-on alarms without persisting them, and retains only the user's explicit choices.
- **Scope prompt is an in-popover overlay** (`ScopePromptView`), not a system
  `confirmationDialog` — the latter's buttons are unclickable inside a `MenuBarExtra(.window)`.

**Invariant.** `ArmedConfig` decodes snapshots written before `fromSeries` existed (custom
`init(from:)`); a non-optional default would otherwise drop all saved state on upgrade.

## 2. Staying reachable — global hot key + quick panel

**Goal.** Reach the app even when its menu-bar icon is hidden (e.g. behind the notch).

**Design.** `GlobalHotKey` registers **⌃⌥⌘M** via Carbon `RegisterEventHotKey` — no Accessibility
permission (unlike an `NSEvent` global monitor). It posts `.meetingAlarmSummon`;
`QuickPanelController` toggles a floating `NSPanel` hosting the same `RootView` as the popover.
There is no official API to open a `MenuBarExtra` window, so we host our own (TD-6, TD-8).

## 3. Launch at login

`LoginItem` wraps `SMAppService.mainApp` (macOS 13+); the Settings toggle reflects live status and
reverts if the system refuses. Also visible under System Settings → General → Login Items.

## 4. Accessibility & keyboard

Esc closes the popover / cancels the recurring prompt; ⌘←/→ day nav, ⌘T today, ⌘R refresh, ⌘Q
quit; VoiceOver labels + `.help` tooltips on every icon-only control; a `.announcementRequested`
when an alarm fires; `@ScaledMetric` list sizing for Dynamic Type. The overlay keeps its own
Esc-dismiss and white-on-scrim contrast.

## 5. Smaller decisions

- **Default alarm color = OS accent** (`SystemAccent` → `RGBAColor`), injected as `Store`'s
  default so a fresh install matches the system; existing choices are preserved.
- **Color picker** is presented via `ColorPanelController` (activate app + order `NSColorPanel`
  front) because SwiftUI's `ColorPicker` opens it behind the frontmost app for an accessory app.

## 6. Harness additions

Verified [module map](../generated/repo-map.md) + `check-docs` drift gate; `make ci`
(CI-parity) + git hooks (`make hooks`); on-demand mutation testing (`make mutation`); a ratcheted
coverage floor; a pinned Xcode (`.xcode-version` + `setup-xcode`); `CHANGELOG.md`; and a PR
template carrying the Definition of Done. See [`../../CONTRIBUTING.md`](../../CONTRIBUTING.md).
