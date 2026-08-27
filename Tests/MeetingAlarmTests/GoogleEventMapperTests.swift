import Foundation
@testable import MeetingAlarm
import Testing

@Suite("GoogleEventMapper")
struct GoogleEventMapperTests {
    let json = Data("""
    {"items":[
      {"id":"e1","summary":"Standup",
       "start":{"dateTime":"2026-08-26T09:00:00Z"},
       "end":{"dateTime":"2026-08-26T09:30:00Z"}},
      {"id":"e2","summary":"All Day Offsite",
       "start":{"date":"2026-08-27"},"end":{"date":"2026-08-28"}}
    ]}
    """.utf8)

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
        #expect(meeting.id == "google:acc-1:e1:2026-08-26")
    }

    @Test("A recurring instance carries a series id; a one-off has none")
    func recurringSeriesId() throws {
        let data = Data("""
        {"items":[
          {"id":"e1_20260826T090000Z","summary":"Standup","recurringEventId":"masterABC",
           "start":{"dateTime":"2026-08-26T09:00:00Z"},
           "end":{"dateTime":"2026-08-26T09:30:00Z"}},
          {"id":"solo","summary":"One-off",
           "start":{"dateTime":"2026-08-26T11:00:00Z"},
           "end":{"dateTime":"2026-08-26T11:30:00Z"}}
        ]}
        """.utf8)
        let meetings = try GoogleEventMapper.meetings(
            fromEventsJSON: data, accountId: "acc-1", accountLabel: "me@example.com"
        )
        #expect(meetings.first { $0.title == "Standup" }?
            .seriesId == "google:acc-1:series:masterABC")
        #expect(meetings.first { $0.title == "One-off" }?.seriesId == nil)
    }

    @Test("A missing summary becomes a sensible placeholder title")
    func missingSummary() throws {
        let data = Data("""
        {"items":[{"id":"e3",
          "start":{"dateTime":"2026-08-26T10:00:00Z"},
          "end":{"dateTime":"2026-08-26T10:15:00Z"}}]}
        """.utf8)
        let meetings = try GoogleEventMapper.meetings(
            fromEventsJSON: data, accountId: "a", accountLabel: "x"
        )
        #expect(meetings.first?.title == "(No title)")
    }
}
