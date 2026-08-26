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

> Status: **v1 functional.** The menu-bar checklist, EventKit + multi-account Google
> sources, the overlay engine, snooze, and persistence are implemented and tested.
> Design lives in [`docs/design-docs/`](docs/design-docs/2026-08-26-meeting-alarm-design.md);
> the build plan is in [`docs/execution-plans/`](docs/execution-plans/).

## How you use it

Click the menu-bar bell to open the popover:

- **Meetings** — a checklist of the selected day's events (default **Today**), with a
  **‹ prev · Today · next ›** navigator. **Check** a row to arm a reminder; pick its
  preset (Blast / Gentle Ramp) from the row. Arming persists across days and relaunches.
- **Test Alarm** (footer) fires the overlay immediately so you can see/hear it.
- When an alarm fires: the overlay covers every display with a live countdown, **Snooze**
  buttons, and **Dismiss**. **Esc always dismisses** — you can never get trapped.
- **Settings** — calendar source, default preset, and snooze intervals.
- **Accounts** — connect one or more Google accounts (direct API).

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
- **Direct Google Calendar** — talks straight to Google, independent of macOS. One-time
  setup of your own OAuth client (free):
  1. Go to the [Google Cloud Console](https://console.cloud.google.com/) and create (or
     pick) a project.
  2. **APIs & Services → Library →** enable the **Google Calendar API**.
  3. **APIs & Services → OAuth consent screen →** choose **External**, fill the required
     app name/email, and under **Test users** add your own Google address. (Staying in
     "testing" is fine for personal use.)
  4. **APIs & Services → Credentials → Create credentials → OAuth client ID →**
     Application type **Desktop app**. Copy the **client ID** and **client secret**.
  5. In Meeting Alarm's **Accounts** tab, paste the client ID + secret, **Save
     credentials**, then **Add account** — your browser opens Google's consent page; approve
     it and the account appears. Repeat **Add account** for more accounts; all their
     meetings merge into the day list, each labeled by email.

  Scopes requested are read-only: `calendar.events.readonly` (+ `openid`, `email` to label
  the account). Tokens are stored in your **Keychain**, never on disk in plaintext.

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
