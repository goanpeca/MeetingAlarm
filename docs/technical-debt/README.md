# Technical Debt

Explicit, categorized tracking of known issues so they surface instead of rotting.
Add a row when you knowingly defer something; remove it when fixed (note the fix in
the commit).

Format: `| id | domain/layer | description | severity | added |`

| id | domain | description | severity | added |
|----|--------|-------------|----------|-------|
| TD-1 | Architecture | Single-module layering is enforced by a framework-import script, not by the compiler. Optional hardening: split layers into SwiftPM targets so an upward-only import becomes a compile error. | low | 2026-08-26 |
| TD-2 | Build/CI | `scripts/coverage-gate.sh` parses `llvm-cov` JSON; verified locally (~95% core). Confirm the `llvm-cov`/xctest paths resolve on the GitHub `macos-latest` image on first CI run. | low | 2026-08-26 |
| TD-3 | Calendar | The Google end-to-end flow (loopback → token exchange → refresh → fetch) is verified manually only; it needs a real OAuth client id/secret, so it is not exercised in CI. Pure pieces (PKCE, URL/body, JSON mapping, merge) are unit-tested. | medium | 2026-08-26 |
| TD-4 | Alarm | `AlarmScheduler` schedules with `Task.sleep`; behavior of very long sleeps across system sleep is backstopped by the `didWake` observer recomputing, not directly tested. Add a sleep/wake test. | low | 2026-08-26 |
| TD-5 | Build/Signing | Dev rebuilds via `swift build` + ad-hoc `codesign` change the signature, so macOS re-forgets the Calendar (TCC) grant and the login-item registration weakens. Intended path is `make app` with the stable "MeetingAlarm Dev" identity (click **Always Allow** on the one-time keychain prompt). | low | 2026-08-27 |
| TD-6 | UI/Runtime | Escape-closes-popover and the quick panel rely on `NSApp.keyWindow?.close()` — there is no official SwiftUI API to dismiss a `MenuBarExtra(.window)`; may break across OS updates. Fallback: an `NSEvent` local key monitor. | medium | 2026-08-27 |
| TD-7 | Calendar | When any series is armed, `materializeSeries` fetches a 60-day horizon on each sync (throttled ≥120s). Cheap on EventKit (local) but a real API call on Google. Consider event-driven materialization or a longer throttle for the Google source. | low | 2026-08-27 |
| TD-8 | UI | `QuickPanel` hosts a second `RootView` instance observing the same coordinator (duplicate view tree). Functionally fine; minor extra memory. Revisit if a shared presentation is warranted. | low | 2026-08-27 |

_No high-severity debt outstanding._
