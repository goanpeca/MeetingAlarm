# Changelog

All notable changes to Meeting Alarm are recorded here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the project aims at
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). Update the `[Unreleased]`
section in the same change that alters behavior.

## [Unreleased]

### Added

- Recurring-event support: a "Repeats" tag on recurring rows, and an in-popover prompt to arm
  **this event only** or the **whole series**; series occurrences are materialized over a
  rolling 60-day horizon so they fire day-to-day. Unarming asks skip-one vs. whole-series.
- Global hot key **⌃⌥⌘M** summons a floating quick panel mirroring the menu-bar popover, so
  the app stays reachable when its menu-bar icon is hidden (e.g. behind the notch).
- **Launch at login** toggle (Settings → Startup) via `SMAppService`.
- App icon (ringing bell + sound waves) built from `scripts/generate-icon.swift`.
- Keyboard shortcuts (⌘←/→ day nav, ⌘T today, ⌘R refresh, ⌘Q quit, Return/Esc in the
  recurring prompt) and VoiceOver labels + tooltips across the controls; Esc closes the
  popover; a VoiceOver announcement when an alarm fires; Dynamic-Type-aware list sizing.
- Sharing: `scripts/package.sh` produces `dist/MeetingAlarm.zip` + `SHARE.md` open steps.
- Harness: verified module map (`docs/architecture/modules.md`) with a `check-docs` drift
  gate, `make ci` CI-parity target, git hooks (`make hooks`), PR template, CONTRIBUTING,
  and mutation-testing config.

### Changed

- Default alarm color follows the OS accent color (System Settings → Appearance → Theme).
- Overlay text sits on a strengthened dark scrim so it's readable over any color/theme.

### Fixed

- Pre-recurring saved snapshots now decode (a non-optional `fromSeries` had broken
  `ArmedConfig` decoding, which would have dropped all armed meetings + settings on upgrade).
- Puzzle input readable in light mode; Dismiss button is neutral grey; edited events refresh
  even while checked; the color picker opens in front for the menu-bar app.

## [0.1.0] — 2026-08-26

- Initial menu-bar app: day-scoped meeting checklist, per-meeting arming with **Blast** and
  sensory-safe **Gentle Ramp** presets, full-screen overlay across all displays with optional
  sound, snooze, dismiss puzzles, and calendar filtering. EventKit + Google calendar sources.
