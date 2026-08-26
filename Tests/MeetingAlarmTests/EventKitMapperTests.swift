import Foundation
@testable import MeetingAlarm
import Testing

@Suite("EventKitMapper")
struct EventKitMapperTests {
    let start = Date(timeIntervalSince1970: 1_756_200_000)

    @Test("Maps a timed event with a stable occurrence id and calendar label")
    func mapsTimed() throws {
        let meeting = try #require(EventKitMapper.meeting(
            identifier: "E1", title: "Sync", start: start,
            end: start.addingTimeInterval(900), isAllDay: false,
            calendarTitle: "Work", occurrenceStart: start
        ))
        #expect(meeting.sourceKind == .eventKit)
        #expect(meeting.title == "Sync")
        #expect(meeting.accountLabel == "Work")
        #expect(meeting.id.hasPrefix("eventkit:E1:"))
    }

    @Test("All-day events are skipped")
    func skipsAllDay() {
        #expect(EventKitMapper.meeting(
            identifier: "E2", title: "Holiday", start: start,
            end: start.addingTimeInterval(86400), isAllDay: true,
            calendarTitle: "Personal", occurrenceStart: start
        ) == nil)
    }

    @Test("An empty title falls back to a placeholder")
    func emptyTitle() throws {
        let meeting = try #require(EventKitMapper.meeting(
            identifier: "E3", title: "", start: start,
            end: start.addingTimeInterval(600), isAllDay: false,
            calendarTitle: "Work", occurrenceStart: start
        ))
        #expect(meeting.title == "(No title)")
    }
}
