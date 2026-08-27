import Foundation
@testable import MeetingAlarm
import Testing

@Suite("EventKitMapper")
struct EventKitMapperTests {
    let start = Date(timeIntervalSince1970: 1_756_200_000)

    private func fields(
        title: String? = "Sync",
        isAllDay: Bool = false,
        url: URL? = nil,
        notes: String? = nil,
        location: String? = nil
    ) -> EventKitMapper.Fields {
        EventKitMapper.Fields(
            identifier: "E1", title: title, start: start, end: start.addingTimeInterval(900),
            isAllDay: isAllDay, calendarTitle: "Work", occurrenceStart: start,
            url: url, notes: notes, location: location
        )
    }

    @Test("Maps a timed event with a stable occurrence id and calendar label")
    func mapsTimed() throws {
        let meeting = try #require(EventKitMapper.meeting(fields()))
        #expect(meeting.sourceKind == .eventKit)
        #expect(meeting.title == "Sync")
        #expect(meeting.accountLabel == "Work")
        #expect(meeting.id.hasPrefix("eventkit:E1:"))
    }

    @Test("All-day events are skipped")
    func skipsAllDay() {
        #expect(EventKitMapper.meeting(fields(title: "Holiday", isAllDay: true)) == nil)
    }

    @Test("An empty title falls back to a placeholder")
    func emptyTitle() throws {
        let meeting = try #require(EventKitMapper.meeting(fields(title: "")))
        #expect(meeting.title == "(No title)")
    }

    @Test("A video link in the notes becomes the join URL")
    func extractsJoinURL() throws {
        let meeting = try #require(EventKitMapper.meeting(
            fields(notes: "Dial in here: https://zoom.us/j/123456789 thanks")
        ))
        #expect(meeting.joinURL?.host == "zoom.us")
    }
}
