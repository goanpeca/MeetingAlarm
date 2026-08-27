# Quality

Grades each domain/layer on how well it meets the golden principles and its test
coverage. Update this in the same change that moves a grade. Grades: **A** solid /
**B** acceptable, gaps noted / **C** needs work / **—** not built yet.

## Coverage bar

- **Gate:** `scripts/coverage-gate.sh`, threshold **85%** on the pure core
  (`CORE_GLOB=/Sources/MeetingAlarm/`, with AppKit/EventKit/URLSession/SwiftUI shells in
  `EXCLUDE`). Current: **~87%** (42 tests). The threshold is **ratcheted** toward actual so a
  real regression fails; the gate also **fails on zero matches**, so it can't pass vacuously.
- Thin shells (overlay window, scheduler timers, EventKit query, UI) are outside
  the measured core; they are covered by the manual checklist in the design doc §11/§13.

## Grades

| Domain | Grade | Notes / gaps |
|--------|:-----:|--------------|
| Models | A | `Meeting`, `SensoryProfile` (+ `overlayOpacity`), `DayWindow`, `DurationText`, `ArmedConfig`, `AlarmOverrides`, `SeriesMaterializer` — presets, Codable, ramp, duration, and series math unit-tested. |
| State | A | `Store` (armed/snooze/series/overrides/settings) round-trips tested, including a legacy-snapshot decode. |
| Calendar (Services) | B | Pure `EventKitMapper`, `MeetingMerge`, `MeetingLink`, `NotesSanitizer` unit-tested; the EventKit query (`EventKitSource`) is a shell verified manually. |
| Alarm (Services) | B | `AlarmMath` (fire/snooze) unit-tested; `AlarmScheduler` timers, `OverlayController` (multi-display, Esc), `SoundPlayer` are shells verified via **Test Alarm**. |
| Runtime/UI | B | Day-list checklist, per-alarm overrides, and settings implemented; verified by launching the app. |

## Open gaps (tracked)

- Overlay Esc-dismiss safety is verified manually; an automated UI/host test would harden it.
- `AlarmScheduler` uses `Task.sleep`; long sleeps across system sleep are backstopped by the
  wake observer re-computing. A dedicated sleep/wake test would raise this grade to A.
