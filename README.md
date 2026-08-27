# Meeting Alarm

[![CI](https://github.com/goanpeca/MeetingAlarm/actions/workflows/ci.yml/badge.svg)](https://github.com/goanpeca/MeetingAlarm/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/badge/coverage-%E2%89%A585%25-brightgreen)](docs/QUALITY_SCORE.md)
![Platform](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.3-orange)

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

> Status: **v1 functional.** The menu-bar checklist, the EventKit (macOS Calendar) source,
> the overlay engine, snooze, and persistence are implemented and tested.
> Design lives in [`docs/design-docs/`](docs/design-docs/2026-08-26-meeting-alarm-design.md);
> the build plan is in [`docs/exec-plans/`](docs/exec-plans/).

## How you use it

Click the menu-bar bell to open the popover:

- **Meetings** — a checklist of the selected day's events (default **Today**), with a
  **‹ prev · Today · next ›** navigator. **Check** a row to arm a reminder; pick its
  preset (Blast / Gentle Ramp) from the row. Arming persists across days and relaunches.
- **Test Alarm** (footer) fires the overlay immediately so you can see/hear it.
- When an alarm fires: the overlay covers every display with a live countdown, **Snooze**
  buttons, and **Dismiss**. **Esc always dismisses** — you can never get trapped.
- **Settings** — default preset, sound, appearance, dismiss gate, and snooze intervals.

## Requirements

- macOS 14+ (developed on macOS 26)
- Xcode 26 / Swift 6.3
- Optional: `brew install swiftformat swiftlint` for lint/format targets

## Build & run

```bash
make test    # unit tests (requires full Xcode — see below)
make app     # build + sign MeetingAlarm.app
make run     # build the app bundle and open it
```

`Package.swift` also opens directly in Xcode 26.

### Stable signing (automatic)

macOS ties the Calendar permission to the app's code signature. Ad-hoc signatures change
every rebuild, so macOS keeps re-forgetting the grant. To avoid that, `make app` signs with
a **stable, self-signed identity** named `MeetingAlarm Dev`. The first `make app` creates
that identity for you (via `scripts/ensure-signing-identity.sh`) and reuses it on every
later build, so Calendar access sticks across rebuilds. No manual setup — clone and
`make app` and it just works. If the identity can't be created (e.g. CI), it falls back to
ad-hoc automatically.

The identity is self-signed and local: it lives only in your login keychain and is never
committed or shared, so **each person who clones the repo gets their own on first build**.
It shows as untrusted, which is fine for local use. Bring your own with
`CODESIGN_IDENTITY="Developer ID Application: …" make app` if you have a real one. If
Calendar access still misbehaves after a change, reset it once:
`tccutil reset Calendar com.goanpeca.MeetingAlarm`.

### Running the tests

`make test` uses Apple's swift-testing framework (`import Testing`), which ships with
**full Xcode**, not the Command Line Tools. If tests fail with `no such module 'Testing'`,
point the toolchain at Xcode once:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

The app itself (`make app` / `make run`) builds fine under either toolchain.

## Calendar setup

The app reads meetings from **macOS Calendar (EventKit)**. Add your Google (or
iCloud/Exchange) account in **System Settings → Internet Accounts** if it isn't already,
launch the app, and click **Allow** on the calendar permission prompt. No credentials or
API setup needed — the app reads events through macOS and nothing leaves your Mac.

> Direct Google Calendar (talking straight to the Google API) is not available right now.
> It may return later as an optional source; for now, connect Google through Internet
> Accounts as above.

## Project layout

See [`AGENTS.md`](AGENTS.md) for the navigation map, and
[`ARCHITECTURE.md`](ARCHITECTURE.md) for the layer
diagram. In short: `Models` (pure) → `State` → `Services` (calendar + alarm) →
`Runtime/UI`, with imports pointing up only.

## Development

```bash
make scan    # layers + format-check + lint (run before committing)
make coverage
```

Conventions: files ≤ 250 lines, no `print` (use `os.Logger`), secrets only in
Keychain, docs kept in sync. Details in
[`docs/design-docs/core-beliefs.md`](docs/design-docs/core-beliefs.md).
