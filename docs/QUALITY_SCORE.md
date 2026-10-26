# Quality

Grades each domain/layer on how well it meets the golden principles and its test
coverage. Update this in the same change that moves a grade. Grades: **A** solid /
**B** acceptable, gaps noted / **C** needs work / **—** not built yet.

## Coverage bar

- **Gate:** `scripts/coverage-gate.sh`, threshold **90%** on the pure core
  (`CORE_GLOB=/Sources/MeetingAlarm/`, with AppKit/EventKit/URLSession/SwiftUI shells listed in
  `scripts/non-core-files.txt`). Current: **~95%** (81 tests). The threshold is **ratcheted**
  toward actual so a real regression fails; the gate also **fails on zero matches**, so it can't
  pass vacuously. The same shell list scopes mutation testing, so the two can't disagree on what
  the testable core is.
- **Mutation floor:** `make mutation` (weekly in CI, `.github/workflows/mutation.yml`) fails below
  **85%**; current **92%** (51/55 mutants killed) over the same pure core. The 4 reported
  survivors are single-expression `{ $0 … }` closures that fail when the same mutation is applied
  by hand, so they look like Muter instrumentation artifacts rather than test gaps. Ratchet the
  floor up as the score holds.
- Thin shells (overlay window, scheduler timers, EventKit query, UI) are outside
  the measured core; they are covered by the manual checklist in the design doc §11/§13.

## Grades

| Domain | Grade | Notes / gaps |
|--------|:-----:|--------------|
| Models | A | `Meeting`, `SensoryProfile` (+ `overlayOpacity`), `DayWindow`, `DurationText`, `ArmedConfig`, `AlarmOverrides`, `DefaultArming` — presets, Codable, ramp, duration, and arming policy unit-tested. |
| State | A | `Store` (armed/snooze/series/overrides/settings) round-trips tested, including a legacy-snapshot decode. |
| Calendar (Services) | B | Pure `EventKitMapper`, `MeetingMerge`, `MeetingLink`, `NotesSanitizer` unit-tested; the EventKit query (`EventKitSource`) is a shell verified manually. |
| Alarm (Services) | B | `AlarmMath` (fire/snooze) unit-tested; `AlarmScheduler` timers, `OverlayController` (multi-display, Esc), `SoundPlayer` are shells verified via **Test Alarm**. |
| Runtime/UI | B | Day-list checklist, per-alarm overrides, and settings implemented; verified by launching the app. |

## Open gaps (tracked)

- Overlay Esc-dismiss: the *policy* (Esc dismisses under every challenge) is now unit-tested via
  `OverlayKey`; only the thin `NSEvent` monitor wiring in `OverlayController` is verified manually.
- `AlarmScheduler` uses `Task.sleep`; long sleeps across system sleep are backstopped by the
  wake observer re-computing. A dedicated sleep/wake test would raise this grade to A.
