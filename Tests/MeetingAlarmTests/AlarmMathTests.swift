import Foundation
@testable import MeetingAlarm
import Testing

@Suite("AlarmMath")
struct AlarmMathTests {
    let start = Date(timeIntervalSince1970: 1_000_000)

    @Test("fireTime subtracts lead time from the meeting start")
    func fireTimeUsesLead() {
        #expect(AlarmMath.fireTime(meetingStart: start, leadTime: 0) == start)
        #expect(
            AlarmMath.fireTime(meetingStart: start, leadTime: 300)
                == start.addingTimeInterval(-300)
        )
    }

    @Test("snoozeFireTime returns now + interval when before meeting end")
    func snoozeWithinMeeting() {
        let end = start.addingTimeInterval(1800)
        #expect(
            AlarmMath.snoozeFireTime(from: start, interval: 60, meetingEnd: end)
                == start.addingTimeInterval(60)
        )
    }

    @Test("snoozeFireTime refuses a target at or past the meeting end")
    func snoozePastEnd() {
        let end = start.addingTimeInterval(60)
        #expect(AlarmMath.snoozeFireTime(from: start, interval: 60, meetingEnd: end) == nil)
        #expect(AlarmMath.snoozeFireTime(from: start, interval: 120, meetingEnd: end) == nil)
    }
}
