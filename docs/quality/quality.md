# Quality

Grades each domain/layer on how well it meets the golden principles and its test
coverage. Update this in the same change that moves a grade. Grades: **A** solid /
**B** acceptable, gaps noted / **C** needs work / **—** not built yet.

## Coverage bar

- **Gate:** `scripts/coverage-gate.sh`, threshold **70%** line coverage on the pure
  core (`CORE_GLOB=/Sources/MeetingAlarm/Models/` today). Ratchet upward as pure
  logic lands in Services (scheduler fire-time math, JSON mapping, PKCE helpers).
- Thin AppKit/EventKit/URLSession shells are intentionally outside the measured
  core; they are covered by the manual checklist in the design doc §11/§13.

## Grades

| Domain | Grade | Notes / gaps |
|--------|:-----:|--------------|
| Models | A | `Meeting`, `SensoryProfile`, `RGBAColor` implemented; presets, Codable, and the Gentle-Ramp `overlayOpacity` curve (incl. Reduce-Motion) unit-tested at 100%. |
| State | — | Not built yet (`Store`, `Keychain`). |
| Calendar (Services) | — | `CalendarSource` protocol defined; EventKit/Google impls pending. |
| Alarm (Services) | — | Scheduler/overlay/sound pending. Fire-time math must land with tests. |
| Runtime/UI | B | Scaffold menu-bar shell only; menu/settings pending. |

## Open gaps (tracked)

- Scheduler `fireTime` needs pure implementation + edge-case tests (overdue, wake,
  all-day exclusion) before it counts toward the core coverage denominator.
- Google JSON→`Meeting` mapping and PKCE/auth-URL helpers need unit tests.
- Overlay Esc-dismiss safety needs an automated assertion once the overlay exists.
