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

    @Test("fireAction schedules a future target, whether or not an overlay is up")
    func fireActionFuture() {
        let target = start.addingTimeInterval(90)
        #expect(AlarmMath.fireAction(target: target, now: start, isPresenting: false)
            == .schedule(after: 90))
        #expect(AlarmMath.fireAction(target: target, now: start, isPresenting: true)
            == .schedule(after: 90))
    }

    @Test("fireAction fires a due or overdue target when nothing is on screen")
    func fireActionDue() {
        #expect(AlarmMath.fireAction(target: start, now: start, isPresenting: false) == .fireNow)
        #expect(AlarmMath.fireAction(
            target: start.addingTimeInterval(-60), now: start, isPresenting: false
        ) == .fireNow)
    }

    @Test("fireAction waits on a due or overdue target while an overlay is on screen")
    func fireActionWaits() {
        #expect(AlarmMath.fireAction(target: start, now: start, isPresenting: true) == .wait)
        #expect(AlarmMath.fireAction(
            target: start.addingTimeInterval(-60), now: start, isPresenting: true
        ) == .wait)
    }
}
