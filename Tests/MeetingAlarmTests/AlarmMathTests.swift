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

    @Test("snoozeFireTime returns now + interval when before meeting start")
    func snoozeBeforeStart() {
        let meetingStart = start.addingTimeInterval(1800)
        #expect(
            AlarmMath.snoozeFireTime(from: start, interval: 60, meetingStart: meetingStart)
                == start.addingTimeInterval(60)
        )
    }

    @Test("snoozeFireTime refuses a target at or past the meeting start")
    func snoozePastStart() {
        let meetingStart = start.addingTimeInterval(60)
        #expect(AlarmMath
            .snoozeFireTime(from: start, interval: 60, meetingStart: meetingStart) == nil)
        #expect(AlarmMath
            .snoozeFireTime(from: start, interval: 120, meetingStart: meetingStart) == nil)
    }
}
