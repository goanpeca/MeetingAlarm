# Meeting Alarm v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the menu-bar Meeting Alarm app: dual calendar sources (EventKit + multi-account Google), a configurable overlay with Blast/Gentle-Ramp presets, and snooze.

**Architecture:** Layered single Swift module — `Models` (pure) → `State` (persistence) → `Services` (Calendar + Alarm) → `Runtime/UI`. Pure logic (scheduling math, JSON mapping, PKCE, ramp curve) is extracted into free functions/value types and unit-tested with Swift Testing; AppKit/EventKit/URLSession/SwiftUI are thin shells verified manually via a **Test Alarm** menu item.

**Tech Stack:** Swift 6.3 / Xcode 26, SwiftUI `MenuBarExtra`, AppKit overlay windows, EventKit, URLSession + `Network.NWListener` (Google OAuth PKCE loopback), Security (Keychain), Swift Testing.

**Spec:** `docs/design-docs/2026-08-26-meeting-alarm-design.md`

## Global Constraints

- Swift language mode **v6**; build must pass `swift build -Xswiftc -warnings-as-errors`.
- Files **≤ 250 lines**; no `print` in `Sources/` (use `os.Logger`); enforced by SwiftLint.
- Imports point **up only**; `Models`/`State` must not import AppKit/SwiftUI/EventKit/Network (`scripts/check-layers.sh`). `State` may import `Security`.
- Secrets (OAuth client id/secret, per-account refresh tokens) live **only** in Keychain, keyed by account id; never `UserDefaults`, never logs.
- Calendar scopes are **read-only** (`calendar.events.readonly` + `userinfo.email`).
- **Esc always dismisses** the overlay — a hard safety invariant, independent of any profile.
- Coverage gate: `scripts/coverage-gate.sh` ≥ **70%** on the pure core; `CORE_GLOB` expands to cover new pure-logic files as they land (Models + Alarm math + Calendar mappers).
- Bundle id / logger subsystem: `com.goanpeca.MeetingAlarm`.
- Commits: single line, `< 72` chars, Conventional-Commit prefix, **no** AI attribution.
- Run `make scan` (layers + format + lint) and `make coverage` green before each commit.

---

## File Structure

Already built (scaffold): `Models/Meeting.swift`, `Models/SensoryProfile.swift` (+ `overlayOpacity`), `Calendar/CalendarSource.swift`, `App.swift`, tests, tooling.

To create:

- `Sources/MeetingAlarm/Models/GoogleAccount.swift` — value type `{ id, email }`.
- `Sources/MeetingAlarm/Models/ArmedConfig.swift` — per-meeting armed preset choice.
- `Sources/MeetingAlarm/State/Store.swift` — armed/snooze/settings via `UserDefaults`.
- `Sources/MeetingAlarm/State/SecretStore.swift` — `SecretStore` protocol + in-memory fake.
- `Sources/MeetingAlarm/State/Keychain.swift` — `SecretStore` backed by Security.
- `Sources/MeetingAlarm/State/GoogleAccountStore.swift` — connected-accounts list.
- `Sources/MeetingAlarm/Alarm/AlarmMath.swift` — pure `fireTime` / `snoozeFireTime`.
- `Sources/MeetingAlarm/Alarm/AlarmScheduler.swift` — timers, wake handling (shell).
- `Sources/MeetingAlarm/Alarm/OverlayController.swift` — multi-display windows (shell).
- `Sources/MeetingAlarm/Alarm/OverlayView.swift` — the SwiftUI overlay content.
- `Sources/MeetingAlarm/Alarm/SoundPlayer.swift` — optional `NSSound` (shell).
- `Sources/MeetingAlarm/Calendar/GoogleEventMapper.swift` — pure JSON → `[Meeting]`.
- `Sources/MeetingAlarm/Calendar/MeetingMerge.swift` — pure merge/sort across accounts.
- `Sources/MeetingAlarm/Calendar/GoogleAuth.swift` — PKCE helpers (pure) + flow (shell).
- `Sources/MeetingAlarm/Calendar/GoogleCalendarSource.swift` — REST fan-out (shell).
- `Sources/MeetingAlarm/Calendar/EventKitMapper.swift` — pure EKEvent-fields → `Meeting`.
- `Sources/MeetingAlarm/Calendar/EventKitSource.swift` — EventKit query (shell).
- `Sources/MeetingAlarm/Logging.swift` — shared `os.Logger` factory.
- `Sources/MeetingAlarm/AppCoordinator.swift` — wires Store + source + scheduler.
- `Sources/MeetingAlarm/UI/MenuContentView.swift`, `UI/SettingsView.swift`, `UI/AccountsView.swift`.
- Tests mirror each pure file under `Tests/MeetingAlarmTests/`.

Split rule: keep a file to one type/responsibility so it stays under 250 lines.

---

## Task 1: Logging + shared Logger

**Files:**
- Create: `Sources/MeetingAlarm/Logging.swift`

**Interfaces:**
- Produces: `enum Log { static func make(_ category: String) -> Logger }`

- [ ] **Step 1: Implement**

```swift
import OSLog

/// One place to mint subsystem-scoped loggers. Golden rule: no `print`.
enum Log {
    static let subsystem = "com.goanpeca.MeetingAlarm"
    static func make(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
```

- [ ] **Step 2: Verify build + layers + lint**

Run: `swift build && ./scripts/check-layers.sh && swiftlint --strict`
Expected: build succeeds; `check-layers: OK`; 0 violations.

- [ ] **Step 3: Commit**

```bash
git add Sources/MeetingAlarm/Logging.swift
git commit -m "feat: add shared os.Logger factory"
```

---

## Task 2: Models — GoogleAccount + ArmedConfig

**Files:**
- Create: `Sources/MeetingAlarm/Models/GoogleAccount.swift`
- Create: `Sources/MeetingAlarm/Models/ArmedConfig.swift`
- Test: `Tests/MeetingAlarmTests/ModelsCodableTests.swift`

**Interfaces:**
- Produces: `struct GoogleAccount: Codable, Sendable, Equatable, Identifiable { let id: String; let email: String }`
- Produces: `struct ArmedConfig: Codable, Sendable, Equatable { var presetName: String; var meeting: Meeting }` — carries a snapshot of the armed meeting so the scheduler can fire it regardless of which day the list is showing.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import MeetingAlarm

@Suite("Models Codable")
struct ModelsCodableTests {
    @Test("GoogleAccount round-trips and is identified by id")
    func googleAccount() throws {
        let account = GoogleAccount(id: "acc-1", email: "me@example.com")
        let data = try JSONEncoder().encode(account)
        #expect(try JSONDecoder().decode(GoogleAccount.self, from: data) == account)
        #expect(account.id == "acc-1")
    }

    @Test("ArmedConfig carries its meeting and round-trips")
    func armedConfig() throws {
        let meeting = Meeting(id: "m1", title: "Sync",
                              start: Date(timeIntervalSince1970: 100),
                              end: Date(timeIntervalSince1970: 700),
                              sourceKind: .eventKit, accountLabel: nil)
        let config = ArmedConfig(presetName: "Gentle Ramp", meeting: meeting)
        let data = try JSONEncoder().encode(config)
        #expect(try JSONDecoder().decode(ArmedConfig.self, from: data) == config)
        #expect(config.meeting.id == "m1")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ModelsCodableTests`
Expected: FAIL — `GoogleAccount` / `ArmedConfig` not defined.

- [ ] **Step 3: Implement**

`GoogleAccount.swift`:

```swift
import Foundation

/// A connected Google account. Its tokens live in Keychain keyed by `id`; only
/// this non-secret descriptor is persisted in UserDefaults.
struct GoogleAccount: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let email: String
}
```

`ArmedConfig.swift`:

```swift
import Foundation

/// Per-meeting arming choice: which preset fires, plus a snapshot of the meeting
/// so the scheduler can fire it independent of the day currently shown in the list.
struct ArmedConfig: Codable, Sendable, Equatable {
    var presetName: String
    var meeting: Meeting
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ModelsCodableTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/MeetingAlarm/Models/ Tests/MeetingAlarmTests/ModelsCodableTests.swift
git commit -m "feat: add GoogleAccount and ArmedConfig models"
```

---

## Task 3: Alarm math (fireTime + snoozeFireTime)

**Files:**
- Create: `Sources/MeetingAlarm/Alarm/AlarmMath.swift`
- Test: `Tests/MeetingAlarmTests/AlarmMathTests.swift`

**Interfaces:**
- Consumes: `Meeting`, `SensoryProfile`.
- Produces: `enum AlarmMath { static func fireTime(meetingStart: Date, leadTime: TimeInterval) -> Date; static func snoozeFireTime(from now: Date, interval: TimeInterval, meetingEnd: Date) -> Date? }`

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import MeetingAlarm

@Suite("AlarmMath")
struct AlarmMathTests {
    let start = Date(timeIntervalSince1970: 1_000_000)

    @Test("fireTime subtracts lead time from the meeting start")
    func fireTimeUsesLead() {
        #expect(AlarmMath.fireTime(meetingStart: start, leadTime: 0) == start)
        #expect(AlarmMath.fireTime(meetingStart: start, leadTime: 300) == start.addingTimeInterval(-300))
    }

    @Test("snoozeFireTime returns now + interval when before meeting end")
    func snoozeWithinMeeting() {
        let now = start
        let end = start.addingTimeInterval(1800)
        #expect(AlarmMath.snoozeFireTime(from: now, interval: 60, meetingEnd: end) == now.addingTimeInterval(60))
    }

    @Test("snoozeFireTime refuses a target at or past the meeting end")
    func snoozePastEnd() {
        let now = start
        let end = start.addingTimeInterval(60)
        #expect(AlarmMath.snoozeFireTime(from: now, interval: 60, meetingEnd: end) == nil)
        #expect(AlarmMath.snoozeFireTime(from: now, interval: 120, meetingEnd: end) == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AlarmMathTests`
Expected: FAIL — `AlarmMath` not defined.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Pure scheduling arithmetic — no timers, no side effects, fully unit-tested.
enum AlarmMath {
    /// When the overlay should begin: `meetingStart − leadTime`.
    static func fireTime(meetingStart: Date, leadTime: TimeInterval) -> Date {
        meetingStart.addingTimeInterval(-leadTime)
    }

    /// The next snooze target, or `nil` if it would land at/after the meeting end
    /// (snoozing past the meeting is pointless).
    static func snoozeFireTime(from now: Date, interval: TimeInterval, meetingEnd: Date) -> Date? {
        let target = now.addingTimeInterval(interval)
        return target < meetingEnd ? target : nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AlarmMathTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Extend coverage glob + commit**

Edit `scripts/coverage-gate.sh`: set `CORE_GLOB` default to `/Sources/MeetingAlarm/` (measure all core; UI shells contribute later tasks' manual coverage). Run `swift test --enable-code-coverage && ./scripts/coverage-gate.sh` — expect ≥ 70%.

```bash
git add Sources/MeetingAlarm/Alarm/AlarmMath.swift Tests/MeetingAlarmTests/AlarmMathTests.swift scripts/coverage-gate.sh
git commit -m "feat: add pure alarm scheduling math with snooze"
```

> Note: after this task the coverage denominator includes upcoming shell files. Keep `CORE_GLOB` at Models + Alarm math + Calendar mappers if shells drag it below 70 — set `CORE_GLOB` to a regex alternation in the script rather than one path. Decide when Task 12 lands.

---

## Task 3b: DayWindow (pure day math) — MVP day list

**Files:**
- Create: `Sources/MeetingAlarm/Models/DayWindow.swift`
- Test: `Tests/MeetingAlarmTests/DayWindowTests.swift`

**Interfaces:**
- Produces: `enum DayWindow { static func interval(for day: Date, calendar: Calendar) -> DateInterval; static func shift(_ day: Date, byDays: Int, calendar: Calendar) -> Date }`. `interval` is `[startOfDay, startOfNextDay)`.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import MeetingAlarm

@Suite("DayWindow")
struct DayWindowTests {
    var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    @Test("interval covers exactly the calendar day [startOfDay, nextDay)")
    func dayInterval() {
        let noon = Date(timeIntervalSince1970: 1_756_209_600) // 2026-08-26 12:00 UTC
        let interval = DayWindow.interval(for: noon, calendar: utc)
        #expect(interval.duration == 86_400)
        #expect(utc.component(.hour, from: interval.start) == 0)
    }

    @Test("shift moves whole days forward and back")
    func shiftDays() {
        let noon = Date(timeIntervalSince1970: 1_756_209_600)
        let tomorrow = DayWindow.shift(noon, byDays: 1, calendar: utc)
        #expect(tomorrow.timeIntervalSince(noon) == 86_400)
        let yesterday = DayWindow.shift(noon, byDays: -1, calendar: utc)
        #expect(noon.timeIntervalSince(yesterday) == 86_400)
    }
}
```

- [ ] **Step 2: Run to verify fail**

Run: `swift test --filter DayWindow`
Expected: FAIL — `DayWindow` not defined.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Pure day math: the interval covering a calendar day, and day navigation.
enum DayWindow {
    static func interval(for day: Date, calendar: Calendar) -> DateInterval {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }

    static func shift(_ day: Date, byDays days: Int, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: days, to: day) ?? day.addingTimeInterval(Double(days) * 86_400)
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter DayWindow`
Expected: PASS (2 tests). (DST days won't be exactly 86_400 in a local zone — the test pins UTC, which is correct.)

- [ ] **Step 5: Commit**

```bash
git add Sources/MeetingAlarm/Models/DayWindow.swift Tests/MeetingAlarmTests/DayWindowTests.swift
git commit -m "feat: add pure DayWindow day-interval and navigation math"
```

---

## Task 4: Google event mapper (pure JSON → [Meeting])

**Files:**
- Create: `Sources/MeetingAlarm/Calendar/GoogleEventMapper.swift`
- Test: `Tests/MeetingAlarmTests/GoogleEventMapperTests.swift`

**Interfaces:**
- Consumes: `Meeting`, `SourceKind`.
- Produces: `enum GoogleEventMapper { static func meetings(fromEventsJSON data: Data, accountId: String, accountLabel: String) throws -> [Meeting] }`. Skips all-day events (those with a `date` but no `dateTime`). `Meeting.id = "google:\(accountId):\(eventId):\(startISO)"`.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import MeetingAlarm

@Suite("GoogleEventMapper")
struct GoogleEventMapperTests {
    let json = """
    {"items":[
      {"id":"e1","summary":"Standup",
       "start":{"dateTime":"2026-08-26T09:00:00Z"},
       "end":{"dateTime":"2026-08-26T09:30:00Z"}},
      {"id":"e2","summary":"All Day Offsite",
       "start":{"date":"2026-08-27"},"end":{"date":"2026-08-28"}}
    ]}
    """.data(using: .utf8)!

    @Test("Maps timed events, skips all-day, stamps account + stable id")
    func mapsTimedEvents() throws {
        let meetings = try GoogleEventMapper.meetings(
            fromEventsJSON: json, accountId: "acc-1", accountLabel: "me@example.com"
        )
        #expect(meetings.count == 1)
        let meeting = try #require(meetings.first)
        #expect(meeting.title == "Standup")
        #expect(meeting.sourceKind == .google)
        #expect(meeting.accountLabel == "me@example.com")
        #expect(meeting.id == "google:acc-1:e1:2026-08-26T09:00:00Z")
    }

    @Test("A missing summary becomes a sensible placeholder title")
    func missingSummary() throws {
        let data = """
        {"items":[{"id":"e3",
          "start":{"dateTime":"2026-08-26T10:00:00Z"},
          "end":{"dateTime":"2026-08-26T10:15:00Z"}}]}
        """.data(using: .utf8)!
        let meetings = try GoogleEventMapper.meetings(fromEventsJSON: data, accountId: "a", accountLabel: "x")
        #expect(meetings.first?.title == "(No title)")
    }
}
```

- [ ] **Step 2: Run to verify fail**

Run: `swift test --filter GoogleEventMapperTests`
Expected: FAIL — `GoogleEventMapper` not defined.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Pure decode of the Google Calendar `events.list` response into `[Meeting]`.
/// Timed events only (an all-day event has `start.date` but no `start.dateTime`).
enum GoogleEventMapper {
    private struct Response: Decodable { let items: [Item]? }
    private struct Item: Decodable {
        let id: String
        let summary: String?
        let start: When
        let end: When
    }
    private struct When: Decodable {
        let dateTime: String?
        let date: String?
    }

    static func meetings(
        fromEventsJSON data: Data,
        accountId: String,
        accountLabel: String
    ) throws -> [Meeting] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return (response.items ?? []).compactMap { item in
            guard let startISO = item.start.dateTime, let endISO = item.end.dateTime,
                  let start = formatter.date(from: startISO),
                  let end = formatter.date(from: endISO)
            else { return nil } // skip all-day / unparseable
            return Meeting(
                id: "google:\(accountId):\(item.id):\(startISO)",
                title: item.summary ?? "(No title)",
                start: start,
                end: end,
                sourceKind: .google,
                accountLabel: accountLabel
            )
        }
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter GoogleEventMapperTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/MeetingAlarm/Calendar/GoogleEventMapper.swift Tests/MeetingAlarmTests/GoogleEventMapperTests.swift
git commit -m "feat: add pure Google event JSON mapper"
```

---

## Task 5: Multi-account merge/sort

**Files:**
- Create: `Sources/MeetingAlarm/Calendar/MeetingMerge.swift`
- Test: `Tests/MeetingAlarmTests/MeetingMergeTests.swift`

**Interfaces:**
- Produces: `enum MeetingMerge { static func merged(_ groups: [[Meeting]]) -> [Meeting] }` — flattens, sorts by `start` then `id` (stable, deterministic), keeps duplicates across accounts.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import MeetingAlarm

@Suite("MeetingMerge")
struct MeetingMergeTests {
    func meeting(_ id: String, _ t: TimeInterval) -> Meeting {
        Meeting(id: id, title: id, start: Date(timeIntervalSince1970: t),
                end: Date(timeIntervalSince1970: t + 60), sourceKind: .google, accountLabel: nil)
    }

    @Test("Merges accounts, sorts by start then id, keeps cross-account duplicates")
    func merges() {
        let a = [meeting("a2", 200), meeting("a1", 100)]
        let b = [meeting("b1", 150), meeting("b0", 100)]
        let result = MeetingMerge.merged([a, b])
        #expect(result.map(\.id) == ["a1", "b0", "b1", "a2"])
    }
}
```

- [ ] **Step 2–4: fail → implement → pass**

```swift
import Foundation

/// Deterministic flatten + sort of per-account meeting lists.
enum MeetingMerge {
    static func merged(_ groups: [[Meeting]]) -> [Meeting] {
        groups.flatMap { $0 }.sorted {
            $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start
        }
    }
}
```

Run: `swift test --filter MeetingMergeTests` → PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MeetingAlarm/Calendar/MeetingMerge.swift Tests/MeetingAlarmTests/MeetingMergeTests.swift
git commit -m "feat: add deterministic multi-account meeting merge"
```

---

## Task 6: EventKit mapper (pure)

**Files:**
- Create: `Sources/MeetingAlarm/Calendar/EventKitMapper.swift`
- Test: `Tests/MeetingAlarmTests/EventKitMapperTests.swift`

**Interfaces:**
- Produces: `enum EventKitMapper { static func meeting(identifier: String, title: String?, start: Date, end: Date, isAllDay: Bool, calendarTitle: String, occurrenceStart: Date) -> Meeting? }`. Returns `nil` for all-day. `id = "eventkit:\(identifier):\(occurrenceISO)"`; `accountLabel = calendarTitle`.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import MeetingAlarm

@Suite("EventKitMapper")
struct EventKitMapperTests {
    let start = Date(timeIntervalSince1970: 1_756_200_000)

    @Test("Maps a timed event with a stable occurrence id and calendar label")
    func mapsTimed() throws {
        let meeting = try #require(EventKitMapper.meeting(
            identifier: "E1", title: "Sync", start: start, end: start.addingTimeInterval(900),
            isAllDay: false, calendarTitle: "Work", occurrenceStart: start))
        #expect(meeting.sourceKind == .eventKit)
        #expect(meeting.title == "Sync")
        #expect(meeting.accountLabel == "Work")
        #expect(meeting.id.hasPrefix("eventkit:E1:"))
    }

    @Test("All-day events are skipped")
    func skipsAllDay() {
        #expect(EventKitMapper.meeting(
            identifier: "E2", title: "Holiday", start: start, end: start.addingTimeInterval(86400),
            isAllDay: true, calendarTitle: "Personal", occurrenceStart: start) == nil)
    }
}
```

- [ ] **Steps 2–4: fail → implement → pass**

```swift
import Foundation

/// Pure mapping from EventKit event fields to `Meeting`, isolated from EKEventStore
/// so it is unit-testable (EKEvent cannot be constructed in tests).
enum EventKitMapper {
    static func meeting(
        identifier: String,
        title: String?,
        start: Date,
        end: Date,
        isAllDay: Bool,
        calendarTitle: String,
        occurrenceStart: Date
    ) -> Meeting? {
        guard !isAllDay else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return Meeting(
            id: "eventkit:\(identifier):\(formatter.string(from: occurrenceStart))",
            title: (title?.isEmpty == false ? title! : "(No title)"),
            start: start,
            end: end,
            sourceKind: .eventKit,
            accountLabel: calendarTitle
        )
    }
}
```

Run: `swift test --filter EventKitMapperTests` → PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MeetingAlarm/Calendar/EventKitMapper.swift Tests/MeetingAlarmTests/EventKitMapperTests.swift
git commit -m "feat: add pure EventKit-to-Meeting mapper"
```

---

## Task 7: Google OAuth pure helpers (PKCE + URLs)

**Files:**
- Create: `Sources/MeetingAlarm/Calendar/GoogleOAuth.swift`
- Test: `Tests/MeetingAlarmTests/GoogleOAuthTests.swift`

**Interfaces:**
- Produces: `struct PKCE { let verifier: String; let challenge: String }`, `enum GoogleOAuth { static func makePKCE(verifier: String) -> PKCE; static func authURL(clientId: String, redirectURI: String, scopes: [String], challenge: String, state: String) -> URL; static func tokenRequestBody(code: String, verifier: String, clientId: String, clientSecret: String, redirectURI: String) -> String }`. Challenge is base64url(SHA256(verifier)) with no padding.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import MeetingAlarm

@Suite("GoogleOAuth helpers")
struct GoogleOAuthTests {
    @Test("PKCE challenge is base64url(SHA256(verifier)), unpadded")
    func pkce() {
        // Known vector from RFC 7636 Appendix B.
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let pkce = GoogleOAuth.makePKCE(verifier: verifier)
        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        #expect(!pkce.challenge.contains("="))
    }

    @Test("authURL contains the required query items")
    func authURL() throws {
        let url = GoogleOAuth.authURL(
            clientId: "cid", redirectURI: "http://127.0.0.1:5555/cb",
            scopes: ["a", "b"], challenge: "CH", state: "ST")
        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name, $0.value) })
        #expect(comps.host == "accounts.google.com")
        #expect(items["client_id"] == "cid")
        #expect(items["code_challenge"] == "CH")
        #expect(items["code_challenge_method"] == "S256")
        #expect(items["scope"] == "a b")
        #expect(items["state"] == "ST")
        #expect(items["response_type"] == "code")
    }

    @Test("token body carries code, verifier and grant type")
    func tokenBody() {
        let body = GoogleOAuth.tokenRequestBody(
            code: "C", verifier: "V", clientId: "cid", clientSecret: "sec",
            redirectURI: "http://127.0.0.1:5555/cb")
        #expect(body.contains("grant_type=authorization_code"))
        #expect(body.contains("code=C"))
        #expect(body.contains("code_verifier=V"))
    }
}
```

- [ ] **Step 2: Run to verify fail**

Run: `swift test --filter "GoogleOAuth helpers"`
Expected: FAIL — `GoogleOAuth` not defined.

- [ ] **Step 3: Implement**

```swift
import CryptoKit
import Foundation

/// Base64url without padding, per RFC 7636.
private func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

struct PKCE: Equatable {
    let verifier: String
    let challenge: String
}

/// Pure OAuth 2.0 (PKCE) helpers — URL and body construction, no networking.
enum GoogleOAuth {
    static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"

    static func makePKCE(verifier: String) -> PKCE {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return PKCE(verifier: verifier, challenge: base64URL(Data(digest)))
    }

    static func authURL(
        clientId: String, redirectURI: String, scopes: [String],
        challenge: String, state: String
    ) -> URL {
        var comps = URLComponents(string: authEndpoint)!
        comps.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: scopes.joined(separator: " ")),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent"),
        ]
        return comps.url!
    }

    static func tokenRequestBody(
        code: String, verifier: String, clientId: String,
        clientSecret: String, redirectURI: String
    ) -> String {
        func enc(_ s: String) -> String {
            s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s
        }
        return [
            "grant_type=authorization_code",
            "code=\(enc(code))",
            "code_verifier=\(enc(verifier))",
            "client_id=\(enc(clientId))",
            "client_secret=\(enc(clientSecret))",
            "redirect_uri=\(enc(redirectURI))",
        ].joined(separator: "&")
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter "GoogleOAuth helpers"`
Expected: PASS (3 tests). If the RFC vector fails, the base64url mapping is wrong — fix before moving on.

- [ ] **Step 5: Commit**

```bash
git add Sources/MeetingAlarm/Calendar/GoogleOAuth.swift Tests/MeetingAlarmTests/GoogleOAuthTests.swift
git commit -m "feat: add pure Google OAuth PKCE + URL helpers"
```

---

## Task 8: SecretStore protocol + in-memory fake + Keychain

**Files:**
- Create: `Sources/MeetingAlarm/State/SecretStore.swift`
- Create: `Sources/MeetingAlarm/State/Keychain.swift`
- Test: `Tests/MeetingAlarmTests/SecretStoreTests.swift`

**Interfaces:**
- Produces: `protocol SecretStore: Sendable { func set(_ value: Data?, for key: String); func get(_ key: String) -> Data? }` with a `set(string:)`/`getString` convenience extension; `final class InMemorySecretStore: SecretStore`; `final class KeychainSecretStore: SecretStore`.

- [ ] **Step 1: Write the failing test (against the fake — Keychain needs an entitled bundle)**

```swift
import Foundation
import Testing
@testable import MeetingAlarm

@Suite("SecretStore")
struct SecretStoreTests {
    @Test("set/get round-trips and delete via nil")
    func roundTrip() {
        let store: SecretStore = InMemorySecretStore()
        store.setString("token", for: "refresh:acc-1")
        #expect(store.getString("refresh:acc-1") == "token")
        store.set(nil, for: "refresh:acc-1")
        #expect(store.get("refresh:acc-1") == nil)
    }
}
```

- [ ] **Step 2: Run to verify fail**

Run: `swift test --filter SecretStore`
Expected: FAIL — types not defined.

- [ ] **Step 3: Implement**

`SecretStore.swift`:

```swift
import Foundation

/// Small secret get/set/delete abstraction so callers (GoogleAuth) can be tested
/// with an in-memory fake — the real Keychain needs an entitled app bundle.
protocol SecretStore: Sendable {
    func set(_ value: Data?, for key: String)
    func get(_ key: String) -> Data?
}

extension SecretStore {
    func setString(_ value: String?, for key: String) {
        set(value.map { Data($0.utf8) }, for: key)
    }

    func getString(_ key: String) -> String? {
        get(key).flatMap { String(data: $0, encoding: .utf8) }
    }
}

/// Test/dev store. Thread-safe via a lock so it can be `Sendable`.
final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    func set(_ value: Data?, for key: String) {
        lock.lock(); defer { lock.unlock() }
        storage[key] = value
    }

    func get(_ key: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]
    }
}
```

`Keychain.swift`:

```swift
import Foundation
import Security

/// `SecretStore` backed by the login Keychain (generic password items).
final class KeychainSecretStore: SecretStore, @unchecked Sendable {
    private let service: String

    init(service: String = "com.goanpeca.MeetingAlarm") {
        self.service = service
    }

    func set(_ value: Data?, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        guard let value else { return }
        var add = query
        add[kSecValueData as String] = value
        SecItemAdd(add as CFDictionary, nil)
    }

    func get(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter SecretStore` → PASS. Then `./scripts/check-layers.sh` (State may import Security) → OK.

- [ ] **Step 5: Commit**

```bash
git add Sources/MeetingAlarm/State/SecretStore.swift Sources/MeetingAlarm/State/Keychain.swift Tests/MeetingAlarmTests/SecretStoreTests.swift
git commit -m "feat: add SecretStore abstraction with Keychain + fake"
```

---

## Task 9: Store (armed + snooze + settings)

**Files:**
- Create: `Sources/MeetingAlarm/State/Store.swift`
- Test: `Tests/MeetingAlarmTests/StoreTests.swift`

**Interfaces:**
- Produces: `@MainActor final class Store: ObservableObject` with `@Published` `armed: [String: ArmedConfig]`, `snoozes: [String: Date]`, `activeSource: SourceKind`, `defaultPresetName: String`, `syncInterval: TimeInterval`, `snoozeIntervals: [TimeInterval]`; methods `arm(_ meeting:preset:)`, `disarm(_ id:)`, `setSnooze(_ id:at:)`, `clearSnooze(_ id:)`, `prunePastSnoozes(now:)`, and `load()`/persistence via an injected `UserDefaults`. Persisted under one JSON blob key `"state.v1"`.

- [ ] **Step 1: Write the failing test (inject a scratch UserDefaults suite)**

```swift
import Foundation
import Testing
@testable import MeetingAlarm

@MainActor
@Suite("Store")
struct StoreTests {
    func makeDefaults() -> UserDefaults {
        let suite = "test.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test("Arming, snoozing, and settings persist and reload")
    func persists() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        let meeting = Meeting(id: "m1", title: "Sync", start: Date(timeIntervalSince1970: 4000),
                              end: Date(timeIntervalSince1970: 6000), sourceKind: .eventKit, accountLabel: nil)
        store.arm(meeting, preset: "Gentle Ramp")
        store.setSnooze("m1", at: Date(timeIntervalSince1970: 5000))
        store.syncInterval = 120
        store.snoozeIntervals = [60, 300]

        let reloaded = Store(defaults: defaults)
        #expect(reloaded.armed["m1"]?.presetName == "Gentle Ramp")
        #expect(reloaded.snoozes["m1"] == Date(timeIntervalSince1970: 5000))
        #expect(reloaded.syncInterval == 120)
        #expect(reloaded.snoozeIntervals == [60, 300])
    }

    @Test("prunePastSnoozes drops targets at or before now")
    func prunes() {
        let store = Store(defaults: makeDefaults())
        store.setSnooze("past", at: Date(timeIntervalSince1970: 100))
        store.setSnooze("future", at: Date(timeIntervalSince1970: 10_000))
        store.prunePastSnoozes(now: Date(timeIntervalSince1970: 5000))
        #expect(store.snoozes["past"] == nil)
        #expect(store.snoozes["future"] != nil)
    }
}
```

- [ ] **Step 2: Run to verify fail**

Run: `swift test --filter Store`
Expected: FAIL — `Store` not defined.

- [ ] **Step 3: Implement** (keep ≤ 250 lines; a `Codable` snapshot struct + load/save)

```swift
import Combine
import Foundation

@MainActor
final class Store: ObservableObject {
    @Published var armed: [String: ArmedConfig] = [:]
    @Published var snoozes: [String: Date] = [:]
    @Published var activeSource: SourceKind = .eventKit
    @Published var defaultPresetName: String = "Blast"
    @Published var syncInterval: TimeInterval = 300
    @Published var snoozeIntervals: [TimeInterval] = [60, 300, 600]

    private let defaults: UserDefaults
    private let key = "state.v1"
    private var loading = false

    private struct Snapshot: Codable {
        var armed: [String: ArmedConfig]
        var snoozes: [String: Date]
        var activeSource: SourceKind
        var defaultPresetName: String
        var syncInterval: TimeInterval
        var snoozeIntervals: [TimeInterval]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func arm(_ meeting: Meeting, preset: String) {
        armed[meeting.id] = ArmedConfig(presetName: preset, meeting: meeting); save()
    }
    func disarm(_ id: String) { armed[id] = nil; save() }
    func setSnooze(_ id: String, at date: Date) { snoozes[id] = date; save() }
    func clearSnooze(_ id: String) { snoozes[id] = nil; save() }

    func prunePastSnoozes(now: Date) {
        snoozes = snoozes.filter { $0.value > now }
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        loading = true
        armed = snap.armed
        snoozes = snap.snoozes
        activeSource = snap.activeSource
        defaultPresetName = snap.defaultPresetName
        syncInterval = snap.syncInterval
        snoozeIntervals = snap.snoozeIntervals
        loading = false
    }

    func save() {
        guard !loading else { return }
        let snap = Snapshot(
            armed: armed, snoozes: snoozes, activeSource: activeSource,
            defaultPresetName: defaultPresetName, syncInterval: syncInterval,
            snoozeIntervals: snoozeIntervals)
        if let data = try? JSONEncoder().encode(snap) { defaults.set(data, forKey: key) }
    }
}
```

> The `@Published` settings (`activeSource`, `syncInterval`, …) are saved on change via `didSet`? No — to keep it simple, callers mutate then the Store saves on the explicit methods; for direct `@Published` edits from SwiftUI, add `.onChange`/a `save()` call in the coordinator. The tests above mutate `syncInterval` directly then create a new Store; make `syncInterval`/`snoozeIntervals` persist by adding `{ didSet { save() } }` to those two published properties (guarded by `loading`).

Add to the two settings properties:

```swift
    @Published var syncInterval: TimeInterval = 300 { didSet { save() } }
    @Published var snoozeIntervals: [TimeInterval] = [60, 300, 600] { didSet { save() } }
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter Store` → PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/MeetingAlarm/State/Store.swift Tests/MeetingAlarmTests/StoreTests.swift
git commit -m "feat: add Store for armed, snooze, and settings state"
```

---

## Task 10: GoogleAccountStore

**Files:**
- Create: `Sources/MeetingAlarm/State/GoogleAccountStore.swift`
- Test: `Tests/MeetingAlarmTests/GoogleAccountStoreTests.swift`

**Interfaces:**
- Produces: `@MainActor final class GoogleAccountStore: ObservableObject` with `@Published var accounts: [GoogleAccount]`, `add(_:)`, `remove(id:)`, persisted via injected `UserDefaults` under `"google.accounts.v1"`. `add` is idempotent by id.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import MeetingAlarm

@MainActor
@Suite("GoogleAccountStore")
struct GoogleAccountStoreTests {
    func defaults() -> UserDefaults { UserDefaults(suiteName: "test.\(UUID())")! }

    @Test("add/remove persist and add is idempotent by id")
    func addRemove() {
        let d = defaults()
        let store = GoogleAccountStore(defaults: d)
        store.add(GoogleAccount(id: "a1", email: "a@x.com"))
        store.add(GoogleAccount(id: "a1", email: "a@x.com")) // dup ignored
        store.add(GoogleAccount(id: "a2", email: "b@x.com"))
        #expect(store.accounts.count == 2)

        let reloaded = GoogleAccountStore(defaults: d)
        #expect(reloaded.accounts.map(\.id) == ["a1", "a2"])
        reloaded.remove(id: "a1")
        #expect(GoogleAccountStore(defaults: d).accounts.map(\.id) == ["a2"])
    }
}
```

- [ ] **Steps 2–4: fail → implement → pass**

```swift
import Combine
import Foundation

@MainActor
final class GoogleAccountStore: ObservableObject {
    @Published private(set) var accounts: [GoogleAccount] = []
    private let defaults: UserDefaults
    private let key = "google.accounts.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let list = try? JSONDecoder().decode([GoogleAccount].self, from: data) {
            accounts = list
        }
    }

    func add(_ account: GoogleAccount) {
        guard !accounts.contains(where: { $0.id == account.id }) else { return }
        accounts.append(account)
        save()
    }

    func remove(id: String) {
        accounts.removeAll { $0.id == id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(accounts) { defaults.set(data, forKey: key) }
    }
}
```

Run: `swift test --filter GoogleAccountStore` → PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MeetingAlarm/State/GoogleAccountStore.swift Tests/MeetingAlarmTests/GoogleAccountStoreTests.swift
git commit -m "feat: add GoogleAccountStore for connected accounts"
```

---

## Task 11: SoundPlayer (shell)

**Files:**
- Create: `Sources/MeetingAlarm/Alarm/SoundPlayer.swift`

**Interfaces:**
- Produces: `@MainActor final class SoundPlayer { func play(_ choice: SoundChoice?, volume: Double, repeats: Bool); func stop() }`. Maps `SoundChoice` to a bundled/system `NSSound`; `nil` → no-op.

- [ ] **Step 1: Implement**

```swift
import AppKit

/// Optional alarm audio. Uses system sounds so no asset bundling is required for v1.
@MainActor
final class SoundPlayer {
    private var sound: NSSound?
    private let log = Log.make("sound")

    func play(_ choice: SoundChoice?, volume: Double, repeats: Bool) {
        stop()
        guard let choice else { return }
        let name: NSSound.Name = switch choice {
        case .chime: "Glass"
        case .alarm: "Sosumi"
        case .ping: "Ping"
        }
        guard let sound = NSSound(named: name) else {
            log.error("missing system sound \(name.rawValue, privacy: .public)")
            return
        }
        sound.volume = Float(max(0, min(1, volume)))
        sound.loops = repeats
        self.sound = sound
        sound.play()
    }

    func stop() {
        sound?.stop()
        sound = nil
    }
}
```

- [ ] **Step 2: Verify build + layers + lint**

Run: `swift build && ./scripts/check-layers.sh && swiftlint --strict`
Expected: green.

- [ ] **Step 3: Commit**

```bash
git add Sources/MeetingAlarm/Alarm/SoundPlayer.swift
git commit -m "feat: add optional sound player"
```

---

## Task 12: OverlayController + OverlayView (shell, manual verify)

**Files:**
- Create: `Sources/MeetingAlarm/Alarm/OverlayView.swift`
- Create: `Sources/MeetingAlarm/Alarm/OverlayController.swift`

**Interfaces:**
- Consumes: `SensoryProfile`, `Meeting`, `SoundPlayer`, `RGBAColor`, `AlarmMath`.
- Produces: `@MainActor final class OverlayController { func present(profile: SensoryProfile, meeting: Meeting, snoozeIntervals: [TimeInterval], onSnooze: @escaping (TimeInterval) -> Void, onDismiss: @escaping () -> Void); func dismiss() }`. One borderless `NSWindow` per `NSScreen`; hosts `OverlayView`. **Esc key → onDismiss.**

- [ ] **Step 1: Implement `OverlayView`** (SwiftUI content: color wash driven by `overlayOpacity`, countdown, snooze/dismiss buttons)

```swift
import SwiftUI

struct OverlayView: View {
    let profile: SensoryProfile
    let meeting: Meeting
    let snoozeIntervals: [TimeInterval]
    let onSnooze: (TimeInterval) -> Void
    let onDismiss: () -> Void

    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var color: Color {
        Color(.sRGB, red: profile.color.red, green: profile.color.green,
              blue: profile.color.blue, opacity: 1)
    }

    private var fraction: Double {
        guard profile.leadTime > 0 else { return 1 }
        let elapsed = profile.leadTime - meeting.start.timeIntervalSince(now)
        return max(0, min(1, elapsed / profile.leadTime))
    }

    private var countdown: String {
        let remaining = Int(meeting.start.timeIntervalSince(now))
        if remaining <= 0 { return "Starting now" }
        return "in \(remaining / 60)m \(remaining % 60)s"
    }

    var body: some View {
        ZStack {
            let motionReduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            color.opacity(profile.overlayOpacity(atFraction: fraction, reduceMotion: motionReduced))
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Text(meeting.title).font(.system(size: 44, weight: .bold))
                if profile.showCountdown { Text(countdown).font(.system(size: 28)) }
                HStack(spacing: 12) {
                    ForEach(snoozeIntervals, id: \.self) { interval in
                        Button("Snooze \(Int(interval / 60))m") { onSnooze(interval) }
                    }
                    Button("Dismiss", role: .cancel) { onDismiss() }
                }.font(.title3)
            }.foregroundStyle(.white)
        }
        .onReceive(tick) { now = $0 }
    }
}
```

- [ ] **Step 2: Implement `OverlayController`** (windows + Esc monitor)

```swift
import AppKit
import SwiftUI

@MainActor
final class OverlayController {
    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    private var onDismiss: (() -> Void)?

    func present(
        profile: SensoryProfile, meeting: Meeting, snoozeIntervals: [TimeInterval],
        onSnooze: @escaping (TimeInterval) -> Void, onDismiss: @escaping () -> Void
    ) {
        dismiss()
        self.onDismiss = onDismiss
        let dismissAll: () -> Void = { [weak self] in self?.dismiss(); onDismiss() }
        let snooze: (TimeInterval) -> Void = { [weak self] i in self?.dismiss(); onSnooze(i) }

        for screen in NSScreen.screens {
            let view = OverlayView(profile: profile, meeting: meeting,
                                   snoozeIntervals: snoozeIntervals,
                                   onSnooze: snooze, onDismiss: dismissAll)
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                                  backing: .buffered, defer: false, screen: screen)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.ignoresMouseEvents = false
            window.contentView = NSHostingView(rootView: view)
            window.setFrame(screen.frame, display: true)
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)

        // Safety invariant: Esc always dismisses.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { dismissAll(); return nil }
            return event
        }
    }

    func dismiss() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}
```

- [ ] **Step 3: Wire a temporary Test Alarm to verify** — add a `Button("Test Alarm")` in `App.swift`'s menu that calls a shared `OverlayController().present(profile: .blast, meeting: sample, …)`. Build the app and run it.

Run: `make app && open MeetingAlarm.app`
Expected (manual): menu-bar bell appears; **Test Alarm** paints a red wash over every display with the title + countdown + Snooze/Dismiss buttons; **Esc** and **Dismiss** both clear it; Snooze clears it (wiring lands in Task 14).

- [ ] **Step 4: Verify checks**

Run: `swift build -Xswiftc -warnings-as-errors && ./scripts/check-layers.sh && swiftlint --strict`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add Sources/MeetingAlarm/Alarm/OverlayView.swift Sources/MeetingAlarm/Alarm/OverlayController.swift Sources/MeetingAlarm/App.swift
git commit -m "feat: add multi-display overlay with snooze and Esc-dismiss"
```

---

## Task 13: Calendar sources (EventKit + Google REST, shells)

**Files:**
- Create: `Sources/MeetingAlarm/Calendar/EventKitSource.swift`
- Create: `Sources/MeetingAlarm/Calendar/GoogleAuth.swift` (flow: browser + loopback + token exchange/refresh)
- Create: `Sources/MeetingAlarm/Calendar/GoogleCalendarSource.swift`

**Interfaces:**
- Consumes: `CalendarSource`, `EventKitMapper`, `GoogleEventMapper`, `MeetingMerge`, `GoogleOAuth`, `SecretStore`, `GoogleAccountStore`.
- Produces: `final class EventKitSource: CalendarSource`; `final class GoogleCalendarSource: CalendarSource`; `actor GoogleAuth` with `func addAccount(clientId:clientSecret:) async throws -> GoogleAccount` and `func accessToken(for accountId:clientId:clientSecret:) async throws -> String`.

- [ ] **Step 1: Implement `EventKitSource`** (query + map via `EventKitMapper`)

```swift
import EventKit
import Foundation

final class EventKitSource: CalendarSource, @unchecked Sendable {
    let kind: SourceKind = .eventKit
    private let store = EKEventStore()
    private let log = Log.make("eventkit")

    func authorize() async throws {
        let granted = try await store.requestFullAccessToEvents()
        if !granted { throw CalendarError.accessDenied }
    }

    func fetchUpcoming(within interval: DateInterval) async throws -> [Meeting] {
        let predicate = store.predicateForEvents(
            withStart: interval.start, end: interval.end, calendars: nil)
        return store.events(matching: predicate).compactMap { event in
            EventKitMapper.meeting(
                identifier: event.eventIdentifier ?? UUID().uuidString,
                title: event.title, start: event.startDate, end: event.endDate,
                isAllDay: event.isAllDay, calendarTitle: event.calendar.title,
                occurrenceStart: event.startDate)
        }.sorted { $0.start < $1.start }
    }
}

enum CalendarError: Error { case accessDenied, notConfigured }
```

- [ ] **Step 2: Implement `GoogleAuth`** — an `actor` that: builds the auth URL (Task 7), opens it with `NSWorkspace.shared.open`, starts an `NWListener` on `127.0.0.1`, captures `code`+`state`, POSTs the token body to the token endpoint, stores the refresh token in `SecretStore` keyed `refresh:<accountId>`, calls `userinfo` for the email, returns `GoogleAccount`. `accessToken(for:)` refreshes using the stored refresh token. (Concrete code — one file, ≤ 250 lines. Uses `URLSession`, `Network`, the `SecretStore` from Task 8, and `GoogleOAuth` from Task 7. Account id = the userinfo `sub`.)

- [ ] **Step 3: Implement `GoogleCalendarSource`** — for each account in `GoogleAccountStore`, get a token from `GoogleAuth`, GET the events endpoint over the interval, map via `GoogleEventMapper`, then `MeetingMerge.merged(...)`. Skip+log a failing account.

- [ ] **Step 4: Verify build + manual sign-in**

Run: `swift build -Xswiftc -warnings-as-errors && ./scripts/check-layers.sh && swiftlint --strict`
Then (manual, needs a Google OAuth desktop client id/secret): trigger **Add account** (Task 14 UI or a temporary button); browser opens Google consent; after approving, the account email appears and a fetch lists your real meetings. EventKit path: grant the permission prompt; your macOS Calendar meetings list.

- [ ] **Step 5: Commit**

```bash
git add Sources/MeetingAlarm/Calendar/EventKitSource.swift Sources/MeetingAlarm/Calendar/GoogleAuth.swift Sources/MeetingAlarm/Calendar/GoogleCalendarSource.swift
git commit -m "feat: add EventKit and multi-account Google calendar sources"
```

---

## Task 14: AppCoordinator + AlarmScheduler wiring

**Files:**
- Create: `Sources/MeetingAlarm/Alarm/AlarmScheduler.swift`
- Create: `Sources/MeetingAlarm/AppCoordinator.swift`

**Interfaces:**
- Consumes: `Store`, `AlarmMath`, `OverlayController`, `SoundPlayer`, active `CalendarSource`.
- Produces: `@MainActor final class AlarmScheduler` (`reschedule(meetings:armed:snoozes:now:)`, `snooze(meetingId:interval:)`, `dismiss(meetingId:)`, wake observer) and `@MainActor final class AppCoordinator: ObservableObject` (`meetings: [Meeting]` for the selected day, `selectedDay: Date` (default `Date()`), `goToDay(_:)`/`nextDay()`/`prevDay()`/`today()` using `DayWindow`, `sync()`, holds Store/scheduler/source). `sync()` fetches `DayWindow.interval(for: selectedDay, calendar: .current)`; scheduling always spans **all armed meetings**, not just the visible day.

- [ ] **Step 1: Implement `AlarmScheduler`** — keeps a `DispatchSourceTimer` per armed meeting at `AlarmMath.fireTime(...)` (and per active snooze at its stored date), fires `OverlayController.present` + `SoundPlayer.play`; on `NSWorkspace.didWakeNotification` re-derives timers and fires overdue-but-not-ended alarms; snooze/dismiss update `Store` and reschedule.

- [ ] **Step 2: Implement `AppCoordinator`** — on launch: `Store.prunePastSnoozes(now:)`, choose source from `Store.activeSource`, `authorize()`, `sync()` on a repeating task at `syncInterval`, and after each sync call `scheduler.reschedule(...)`. Expose actions for the UI (arm/disarm/setSource/addAccount/testAlarm).

- [ ] **Step 3: Replace the scaffold menu** — `App.swift` builds an `AppCoordinator` and renders `MenuContentView` (Task 15). Keep **Test Alarm** wired through the coordinator.

- [ ] **Step 4: Verify**

Run: `swift build -Xswiftc -warnings-as-errors && swift test && ./scripts/check-layers.sh && swiftlint --strict`
Then manual: arm a near-future meeting (or use a 10-second test hook) → overlay fires at fire time; Snooze re-fires after the interval; Dismiss clears; state survives quitting/reopening.

- [ ] **Step 5: Commit**

```bash
git add Sources/MeetingAlarm/Alarm/AlarmScheduler.swift Sources/MeetingAlarm/AppCoordinator.swift Sources/MeetingAlarm/App.swift
git commit -m "feat: wire scheduler and app coordinator with snooze"
```

---

## Task 15: UI (menu list, settings, accounts)

**Files:**
- Create: `Sources/MeetingAlarm/UI/MenuContentView.swift`
- Create: `Sources/MeetingAlarm/UI/SettingsView.swift`
- Create: `Sources/MeetingAlarm/UI/AccountsView.swift`

**Interfaces:**
- Consumes: `AppCoordinator`, `Store`, `GoogleAccountStore`.

- [ ] **Step 1: Implement `MenuContentView` (MVP core)** — a **day navigator** header
  (‹ prev · a label reading "Today"/weekday-date · next ›, bound to `coordinator.selectedDay`,
  defaulting to today) above the **checklist** of `coordinator.meetings` for that day. Each row:
  a `Toggle` bound to `armed[meeting.id] != nil` (checking calls `store.arm(meeting, preset: defaultPresetName)`, unchecking `store.disarm(meeting.id)`) + the title + start–end time + a preset `Picker` (enabled when checked); an `accountLabel` badge when >1 account. Below: a permission/error banner and **Test Alarm**, **Settings…**, **Accounts…**, **Quit** buttons. Empty day → "No events." An armed meeting on another day stays armed (its checkbox shows checked when you navigate back).

- [ ] **Step 2: Implement `SettingsView`** — source `Picker` (EventKit/Google), default preset picker, per-knob controls bound to a custom profile, and a **snooze intervals** editor (add/remove minute values).

- [ ] **Step 3: Implement `AccountsView`** — OAuth client id/secret fields (stored via `SecretStore`), an **Add account** button (runs `GoogleAuth.addAccount`), and the account list with per-row **Remove**.

- [ ] **Step 4: Verify (manual)**

Run: `make app && open MeetingAlarm.app`
Expected: meetings list with working toggles/pickers; adding a second Google account makes both accounts' meetings appear with labels; settings changes persist; snooze intervals editable.

- [ ] **Step 5: Commit**

```bash
git add Sources/MeetingAlarm/UI/
git commit -m "feat: add menu, settings, and accounts UI"
```

---

## Task 16: Docs sync + README setup + quality grades

**Files:**
- Modify: `README.md` (fill the Google Cloud click-by-click steps), `docs/QUALITY_SCORE.md` (grade State/Calendar/Alarm/UI), `docs/design-docs/index.md` (keep `current`), `docs/exec-plans/tech-debt-tracker.md` (resolve/adjust rows).

- [ ] **Step 1: Update README** with the exact Google Cloud OAuth desktop-client steps and the add-account flow.
- [ ] **Step 2: Update quality grades** to reflect what's implemented + tested; note any shells excluded from coverage.
- [ ] **Step 3: Verify full gate**

Run: `make scan && make coverage && swift build -Xswiftc -warnings-as-errors && swift test`
Expected: all green; coverage ≥ 70% on the pure core.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/
git commit -m "docs: finalize setup guide and quality grades for v1"
```

---

## Self-Review

- **Spec coverage:** day-scoped checklist default today + navigator (T3b/T14/T15 — the MVP core), dual sources (T6/T13), multi-account Google (T4/T5/T10/T13/T15), sensory presets + ramp (scaffold + T12), snooze (T3/T9/T12/T14), Esc safety (T12), persistence incl. cross-day arming via `ArmedConfig.meeting` (T2/T9/T14), Keychain secrets (T8), scheduling + wake (T14), UI (T15), harness/quality gates (throughout) — all mapped.
- **Placeholder scan:** pure-logic tasks carry full code + tests; shells (T11–T15) give full interfaces, concrete code for the non-obvious parts, and explicit manual verification with expected results (a window/OAuth flow can't be unit-tested, so manual is the correct gate, not a placeholder).
- **Type consistency:** `Meeting` gains `accountLabel` (spec §5); ids namespaced `google:`/`eventkit:`; `SecretStore.set(_:for:)`/`get` used by `GoogleAuth`; `AlarmMath.fireTime`/`snoozeFireTime` consumed by `AlarmScheduler`; `Store` keys meetings by `Meeting.id`. Consistent across tasks.
