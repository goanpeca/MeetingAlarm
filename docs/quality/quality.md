# Quality

Grades each domain/layer on how well it meets the golden principles and its test
coverage. Update this in the same change that moves a grade. Grades: **A** solid /
**B** acceptable, gaps noted / **C** needs work / **—** not built yet.

## Coverage bar

- **Gate:** `scripts/coverage-gate.sh`, threshold **70%** on the pure core
  (`CORE_GLOB=/Sources/MeetingAlarm/`, with AppKit/EventKit/URLSession/SwiftUI shells in
  `EXCLUDE`). Current: **~95%** (29 tests). The gate **fails on zero matches**, so it can
  never pass vacuously.
- Thin shells (overlay window, scheduler timers, EventKit/Google network, UI) are outside
  the measured core; they are covered by the manual checklist in the design doc §11/§13.

## Grades

| Domain | Grade | Notes / gaps |
|--------|:-----:|--------------|
| Models | A | `Meeting`, `SensoryProfile` (+ `overlayOpacity`), `DayWindow`, `GoogleAccount`, `ArmedConfig` — presets, Codable, ramp, and day math unit-tested. |
| State | A | `Store` (armed/snooze/settings) and `GoogleAccountStore` round-trip tested; `SecretStore` fake tested; `Keychain` is a thin Security shell (manual). |
| Calendar (Services) | B | Pure `GoogleEventMapper`, `EventKitMapper`, `MeetingMerge`, `GoogleOAuth` (PKCE/URLs) unit-tested; EventKit query, Google REST fan-out, and OAuth loopback are shells verified manually (Google needs your OAuth client). |
| Alarm (Services) | B | `AlarmMath` (fire/snooze) unit-tested; `AlarmScheduler` timers, `OverlayController` (multi-display, Esc), `SoundPlayer` are shells verified via **Test Alarm**. |
| Runtime/UI | B | Day-list checklist, settings, and accounts implemented; verified by launching the app. |

## Open gaps (tracked)

- Overlay Esc-dismiss safety is verified manually; an automated UI/host test would harden it.
- The Google end-to-end flow (loopback → token → fetch) is exercised manually — it needs a
  real OAuth client id/secret, so it is not run in CI. See `docs/technical-debt/`.
- `AlarmScheduler` uses `Task.sleep`; long sleeps across system sleep are backstopped by the
  wake observer re-computing. A dedicated sleep/wake test would raise this grade to A.
