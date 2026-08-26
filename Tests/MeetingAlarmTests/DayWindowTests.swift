import Foundation
@testable import MeetingAlarm
import Testing

@Suite("DayWindow")
struct DayWindowTests {
    var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    @Test("interval covers exactly the calendar day [startOfDay, nextDay)")
    func dayInterval() {
        let noon = Date(timeIntervalSince1970: 1_756_209_600) // 2026-08-26 12:00 UTC
        let interval = DayWindow.interval(for: noon, calendar: utc)
        #expect(interval.duration == 86400)
        #expect(utc.component(.hour, from: interval.start) == 0)
        #expect(interval.contains(noon))
    }

    @Test("shift moves whole days forward and back")
    func shiftDays() {
        let noon = Date(timeIntervalSince1970: 1_756_209_600)
        #expect(DayWindow.shift(noon, byDays: 1, calendar: utc).timeIntervalSince(noon) == 86400)
        #expect(noon.timeIntervalSince(DayWindow.shift(noon, byDays: -1, calendar: utc)) == 86400)
    }
}
