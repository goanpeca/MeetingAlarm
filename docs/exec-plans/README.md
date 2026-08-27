# Execution Plans

Version-controlled implementation plans with progress logs. Each plan is a
timestamped file recording what will be built, in what order, and — as work
proceeds — what was attempted and the outcome.

The implementation plan for v1 is produced from the approved
[design doc](../design-docs/2026-08-26-meeting-alarm-design.md) via the
writing-plans workflow and will land here as
`YYYY-MM-DD-meeting-alarm-v1-plan.md`.

Expected build order (from the design):

1. **Models** — `Meeting`, `SensoryProfile` (+ presets). ✅ done in scaffold.
2. **State** — `Store` (UserDefaults), `Keychain` wrapper.
3. **Alarm engine** — `AlarmScheduler.fireTime` (pure, TDD first), `OverlayController`
   (multi-display, Esc-dismiss, Reduce-Motion), `SoundPlayer`. Wire a **Test Alarm**.
4. **EventKit source** — permission flow + `fetchUpcoming`. First end-to-end path.
5. **Google source** — `GoogleAuth` (PKCE loopback) + `GoogleCalendarSource`, behind
   the same protocol; settings field for the OAuth client id/secret.
6. **UI** — meeting list with per-meeting toggle + preset picker; settings pane.
7. **Polish** — sleep/wake handling, error banners, README setup docs.
