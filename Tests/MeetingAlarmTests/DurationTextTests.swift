import Foundation
@testable import MeetingAlarm
import Testing

@Suite("DurationText")
struct DurationTextTests {
    @Test("Formats minutes, whole hours, and combined")
    func formats() {
        #expect(DurationText.format(seconds: 30 * 60) == "30 min")
        #expect(DurationText.format(seconds: 60 * 60) == "1 hr")
        #expect(DurationText.format(seconds: 90 * 60) == "1 hr 30 min")
        #expect(DurationText.format(seconds: 0) == "0 min")
    }

    @Test("A negative interval clamps to zero rather than going negative")
    func clampsNegative() {
        #expect(DurationText.format(seconds: -300) == "0 min")
    }

    @Test("Derives the length from start/end dates")
    func fromDates() {
        let start = Date(timeIntervalSince1970: 0)
        #expect(DurationText.format(from: start, to: start.addingTimeInterval(45 * 60)) == "45 min")
    }
}
