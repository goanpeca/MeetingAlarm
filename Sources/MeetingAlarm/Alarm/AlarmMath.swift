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
}
