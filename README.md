# Meeting Alarm

A macOS **menu-bar app** that makes meetings impossible to miss while you're at the
computer. Arm an extra alarm on any upcoming meeting and, at the moment you choose,
it throws a **full-screen overlay across every display** with an optional sound.

Two built-in alert styles (both fully adjustable):

- **Blast** — at meeting time, an opaque red overlay + loud sound. A blunt,
  can't-miss interrupt.
- **Gentle Ramp** — starts a few minutes early and grows *predictably*, with a live
  countdown and a soft chime. Designed to be **sensory-safe** and to ease you out of
  hyperfocus without a shock. Honors the system **Reduce Motion** setting; **Esc
  always dismisses**.

> Status: **scaffold**. The repo builds, tests, lints, and enforces its own
> architecture today; calendar sync and the alarm engine are being implemented per
> [`docs/execution-plans/`](docs/execution-plans/). Design lives in
> [`docs/design-docs/`](docs/design-docs/2026-08-26-meeting-alarm-design.md).

## Requirements

- macOS 14+ (developed on macOS 26)
- Xcode 26 / Swift 6.3
- Optional: `brew install swiftformat swiftlint` for lint/format targets

## Build & run

```bash
make test    # unit tests
make app     # assemble + ad-hoc-sign MeetingAlarm.app
make run     # build the app bundle and open it
```

`Package.swift` also opens directly in Xcode 26.

## Calendar setup

The app reads meetings from either source, switchable in settings:

- **macOS Calendar (EventKit)** — the simplest path. Add your Google account in
  **System Settings → Internet Accounts** (if it isn't already), launch the app, and
  click **Allow** on the calendar permission prompt. No credentials needed; this
  reads your Google (and iCloud/Exchange) events through macOS.
- **Direct Google Calendar** — talks straight to Google. One-time setup: create a
  Google Cloud project → OAuth consent screen (External; add yourself as a test
  user) → an OAuth client ID of type **Desktop app** → paste the client ID + secret
  into Settings. Scope requested: `calendar.events.readonly`. (Full click-by-click
  steps will be added here when this path lands.)

## Project layout

See [`AGENTS.md`](AGENTS.md) for the navigation map, and
[`docs/architecture/overview.md`](docs/architecture/overview.md) for the layer
diagram. In short: `Models` (pure) → `State` → `Services` (calendar + alarm) →
`Runtime/UI`, with imports pointing up only.

## Development

```bash
make scan    # layers + format-check + lint (run before committing)
make coverage
```

Conventions: files ≤ 250 lines, no `print` (use `os.Logger`), secrets only in
Keychain, docs kept in sync. Details in
[`docs/principles/golden-principles.md`](docs/principles/golden-principles.md).
