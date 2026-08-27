# Module Map

Every Swift file under `Sources/` with a one-line purpose. This map is **mechanically
verified**: `scripts/check-docs.sh` (run in `make scan` / `make ci` / CI) fails if a source
file is missing here or listed here but deleted — so the map can't silently drift from the
code. Add a row in the same change that adds a file.

Layers point up only (see [`overview.md`](../../ARCHITECTURE.md)); the folder is the layer.

## Models — pure value types (no UI/IO)

| File | Purpose |
|------|---------|
| `Sources/MeetingAlarm/Models/ArmedConfig.swift` | Per-meeting arming choice: preset + meeting snapshot, with a `fromSeries` flag for series-materialized entries. |
| `Sources/MeetingAlarm/Models/CalendarInfo.swift` | A calendar's identity/title for the show/hide filter UI. |
| `Sources/MeetingAlarm/Models/DayWindow.swift` | Day → `DateInterval` window and day shifting, timezone-correct. |
| `Sources/MeetingAlarm/Models/DismissChallenge.swift` | Dismiss-gate options (none / hold / math / type-phrase). |
| `Sources/MeetingAlarm/Models/DurationText.swift` | Formats a meeting length as "30 min" / "1 hr 30 min". |
| `Sources/MeetingAlarm/Models/GoogleAccount.swift` | A connected Google account's identity. |
| `Sources/MeetingAlarm/Models/Meeting.swift` | Normalized meeting occurrence: stable id, join URLs, notes, attendees, `seriesId`. |
| `Sources/MeetingAlarm/Models/OccurrenceKey.swift` | Stable per-day key so armed state survives same-day time edits. |
| `Sources/MeetingAlarm/Models/ScopePrompt.swift` | Pending "this event / whole series" question for a recurring action. |
| `Sources/MeetingAlarm/Models/SensoryProfile.swift` | Alarm visual/sound profile + presets; `RGBAColor`, `Effect`. |
| `Sources/MeetingAlarm/Models/SeriesMaterializer.swift` | Pure rule for which series occurrences to schedule. |

## State — persistence (imports Models only)

| File | Purpose |
|------|---------|
| `Sources/MeetingAlarm/State/GoogleAccountStore.swift` | Persists the set of connected Google accounts. |
| `Sources/MeetingAlarm/State/Keychain.swift` | Keychain-backed secret storage. |
| `Sources/MeetingAlarm/State/SecretStore.swift` | Secret-store protocol (seam over the Keychain). |
| `Sources/MeetingAlarm/State/Store.swift` | Persists armed meetings, series rules/skips, snoozes, and all settings (UserDefaults JSON). |

## Calendar (Services) — fetch meetings from a backend

| File | Purpose |
|------|---------|
| `Sources/MeetingAlarm/Calendar/CalendarSource.swift` | Protocol hiding which calendar backend is active. |
| `Sources/MeetingAlarm/Calendar/EventKitMapper.swift` | Pure `EKEvent` fields → `Meeting` mapping. |
| `Sources/MeetingAlarm/Calendar/EventKitSource.swift` | Reads macOS Calendar (EventKit) events. |
| `Sources/MeetingAlarm/Calendar/GoogleAuth.swift` | Google OAuth token lifecycle per account. |
| `Sources/MeetingAlarm/Calendar/GoogleCalendarSource.swift` | Fetches meetings from the Google Calendar API. |
| `Sources/MeetingAlarm/Calendar/GoogleEventMapper.swift` | Pure Google events JSON → `[Meeting]` (incl. `recurringEventId`). |
| `Sources/MeetingAlarm/Calendar/GoogleOAuth.swift` | Pure PKCE OAuth request/URL/body construction. |
| `Sources/MeetingAlarm/Calendar/LoopbackServer.swift` | Localhost redirect server for the OAuth callback. |
| `Sources/MeetingAlarm/Calendar/MeetingLink.swift` | Detects Meet/Zoom/Teams join URLs in event text (pure). |
| `Sources/MeetingAlarm/Calendar/MeetingMerge.swift` | Merges/dedupes meetings across sources (pure). |
| `Sources/MeetingAlarm/Calendar/NotesSanitizer.swift` | Strips calendar boilerplate from notes (pure). |

## Alarm (Services) — fire alarms, draw overlay, play sound

| File | Purpose |
|------|---------|
| `Sources/MeetingAlarm/Alarm/AlarmMath.swift` | Pure fire-time / snooze-time math. |
| `Sources/MeetingAlarm/Alarm/AlarmScheduler.swift` | Arms a timer per armed meeting; fires overlay + sound. |
| `Sources/MeetingAlarm/Alarm/ChallengeGateView.swift` | The dismiss puzzle (math / hold / type-phrase) gate view. |
| `Sources/MeetingAlarm/Alarm/MeetingProvider.swift` | Brand label/color for a join URL (Meet/Zoom/…). |
| `Sources/MeetingAlarm/Alarm/NotesView.swift` | Renders event notes (HTML → AttributedString) on the overlay. |
| `Sources/MeetingAlarm/Alarm/OverlayController.swift` | Presents the full-screen alarm across all displays; VoiceOver announce. |
| `Sources/MeetingAlarm/Alarm/OverlayView.swift` | Overlay content: countdown, join, snooze, dismiss. |
| `Sources/MeetingAlarm/Alarm/SoundPlayer.swift` | Plays the alarm sound (looping with a configurable gap). |

## UI — menu popover, settings, summonable panel

| File | Purpose |
|------|---------|
| `Sources/MeetingAlarm/UI/ColorPanelController.swift` | Presents `NSColorPanel` in front for the accessory app. |
| `Sources/MeetingAlarm/UI/HTMLText.swift` | HTML notes → plain, theme-aware text for the day list. |
| `Sources/MeetingAlarm/UI/MeetingDetailView.swift` | Expanded row detail: attendees + full description. |
| `Sources/MeetingAlarm/UI/MeetingRow.swift` | One meeting row: checkbox, time + duration, disclosure, preset. |
| `Sources/MeetingAlarm/UI/MenuContentView.swift` | Day list + navigator + calendar filter (menu popover). |
| `Sources/MeetingAlarm/UI/QuickPanel.swift` | Floating panel summoned by the global hot key. |
| `Sources/MeetingAlarm/UI/ScopePromptView.swift` | In-popover "this event / whole series" modal. |
| `Sources/MeetingAlarm/UI/SettingsView.swift` | Preferences form. |
| `Sources/MeetingAlarm/UI/SystemAccent.swift` | OS accent color → `RGBAColor` (default alarm color). |

## Runtime — app entry + coordination

| File | Purpose |
|------|---------|
| `Sources/MeetingAlarm/App.swift` | `@main` menu-bar entry + `RootView` (panes, footer, Escape). |
| `Sources/MeetingAlarm/AppCoordinator.swift` | Wires state + source + scheduler; drives the day list. |
| `Sources/MeetingAlarm/AppCoordinator+Scheduling.swift` | Reconcile edited events + materialize armed series. |
| `Sources/MeetingAlarm/AppCoordinator+Sources.swift` | Google-account + calendar-filter actions. |
| `Sources/MeetingAlarm/AppCoordinator+UI.swift` | Day navigation + per-meeting/series arming. |
| `Sources/MeetingAlarm/GlobalHotKey.swift` | Carbon system-wide hot key (no Accessibility permission). |
| `Sources/MeetingAlarm/Logging.swift` | `os.Logger` factory (no `print` in `Sources/`). |
| `Sources/MeetingAlarm/LoginItem.swift` | Launch-at-login via `SMAppService`. |
