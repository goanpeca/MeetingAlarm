# Security Policy

## Supported versions

Meeting Alarm is an actively developed macOS app. Security fixes land on the latest
`main`; please make sure you're on the most recent build before reporting.

## Reporting a vulnerability

Please report security issues **privately** — do not open a public GitHub issue or PR for
them.

- **Email:** goanpeca@gmail.com
- Use a subject line starting with `[MeetingAlarm security]`.
- Include: a description of the issue, the version/commit affected, reproduction steps or a
  proof of concept, and the potential impact.

You'll get an acknowledgement within a few days. Once the issue is confirmed and a fix is
available, the details can be disclosed publicly. Please give a reasonable window for a fix
before any public disclosure.

## Scope

Meeting Alarm runs entirely on your Mac: it reads calendar events through macOS EventKit and
stores its settings locally. It makes no network calls of its own and sends no data off the
device. Reports most relevant to this app include:

- Unintended exposure of calendar data or app settings.
- Ways the full-screen overlay could trap the user (note: **Esc always dismisses** by
  design).
- Local privilege or code-signing / packaging issues in the built app bundle.

Thanks for helping keep Meeting Alarm safe.
