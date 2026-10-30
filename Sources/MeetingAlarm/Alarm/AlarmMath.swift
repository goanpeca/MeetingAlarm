import Foundation

/// Pure scheduling arithmetic — no timers, no side effects, fully unit-tested.
enum AlarmMath {
    /// When the overlay should begin: `meetingStart − leadTime`.
    static func fireTime(meetingStart: Date, leadTime: TimeInterval) -> Date {
        meetingStart.addingTimeInterval(-leadTime)
    }

    /// The next snooze target, or `nil` if it would land at/after the meeting **start**
    /// — a snooze must re-remind you *before* the meeting begins, never after.
    static func snoozeFireTime(
        from now: Date,
        interval: TimeInterval,
        meetingStart: Date
    ) -> Date? {
        let target = now.addingTimeInterval(interval)
        return target < meetingStart ? target : nil
    }

    /// Decide whether an alarm fires now, arms a timer, or waits. Only one overlay is shown at
    /// a time, so a due alarm never replaces (or re-presents) the one on screen.
    static func fireAction(target: Date, now: Date, isPresenting: Bool) -> FireAction {
        if target > now {
            return .schedule(after: target.timeIntervalSince(now))
        }
        return isPresenting ? .wait : .fireNow
    }
}

/// What the scheduler should do with one alarm right now.
enum FireAction: Equatable, Sendable {
    case fireNow
    case schedule(after: TimeInterval)
    /// Due, but an overlay is on screen; re-evaluated on the reschedule after it closes.
    case wait
}
