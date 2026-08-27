# Architecture Overview

A top-level map of the domains and how they layer. The authoritative per-component
contracts live in the [design doc](docs/design-docs/2026-08-26-meeting-alarm-design.md) §5.
For the exhaustive, mechanically-verified list of every file see the
[module map](docs/generated/repo-map.md).

## Domains

| Domain | Responsibility | Key types |
|--------|----------------|-----------|
| Models | Normalized value types, pure | `Meeting`, `SensoryProfile`, `RGBAColor` |
| State | Persistence of settings/secrets | `Store` (UserDefaults), `Keychain` |
| Calendar (Services) | Fetch meetings from a backend | `CalendarSource`, `EventKitSource`, `GoogleCalendarSource`, `GoogleAuth` |
| Alarm (Services) | Fire alarms, draw overlay, play sound | `AlarmScheduler`, `OverlayController`, `SoundPlayer` |
| Runtime/UI | App lifecycle + menu/settings | `MeetingAlarmApp`, `AppCoordinator`, `MenuContentView`, `SettingsView`, `QuickPanel` |

Newer subsystems slot into these same layers: **recurring-series arming**
(`SeriesMaterializer` in Models; materialization in `AppCoordinator+Scheduling`), the
global-hot-key **quick panel** (`GlobalHotKey`, `QuickPanel`), and **launch-at-login**
(`LoginItem`) — all Runtime/UI or below, none reaching down into the pure core.

## Layering (imports point up only)

```
Runtime/UI  ─ imports ─▶ Services ─ imports ─▶ State ─ imports ─▶ Models
   (top)                                                          (bottom)
```

A **lower** layer must never depend on a **higher** one. Concretely:

- **Models** import nothing app-local and no UI/IO frameworks — pure and testable
  without a screen, calendar DB, or network. Colors are plain components
  (`RGBAColor`), not `NSColor`, precisely to keep this true.
- **State** imports Models only (plus `Security` for the Keychain wrapper). No UI,
  calendar, or networking here.
- **Services** may import Models + State and the platform frameworks they need
  (EventKit, Network, URLSession, AppKit for the overlay).
- **Runtime/UI** may import everything below it.

### How this is enforced

This is a single Swift module, so the compiler won't block a cross-layer
reference on its own. We therefore enforce the boundary two ways:

1. **Framework-import purity** — `scripts/check-layers.sh` fails the build if
   `Models/` or `State/` import a forbidden framework (AppKit, SwiftUI, EventKit,
   Network; Security is allowed only in State). This is the mechanical guardrail
   that keeps the pure core pure.
2. **Folder = layer convention** — every source file lives in exactly one layer
   folder, and cross-layer *type* references from a lower to a higher layer are
   caught in review.

> Future hardening (optional): split the layers into separate SwiftPM targets so
> the package dependency graph makes an upward-only import a compile error. Noted
> in the design doc §15; not done in v1 to keep the tree simple.

## Data flow (happy path)

```
Store (settings) ─▶ pick CalendarSource ─▶ fetchUpcoming(24h) ─▶ [Meeting]
      ▲                                                              │
      │ arm/disarm                                                   ▼
   MenuContentView ◀──────────────────────────────────────── list + toggles
      │ arm                                                          │
      ▼                                                              ▼
 AlarmScheduler.fireTime(meeting, profile, now) ─▶ timer ─▶ OverlayController
                                                              + SoundPlayer
                                                              (Esc always dismisses)
```

See the design doc §4/§6 for scheduling, sleep/wake, and edge-case handling.
