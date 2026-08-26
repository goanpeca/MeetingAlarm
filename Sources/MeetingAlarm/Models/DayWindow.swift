import Foundation

/// Pure day math: the interval covering a calendar day, and day navigation. Kept free
/// of UI so "which day is shown" stays testable.
enum DayWindow {
    /// The half-open interval `[startOfDay, startOfNextDay)` for `day` in `calendar`.
    static func interval(for day: Date, calendar: Calendar) -> DateInterval {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86400)
        return DateInterval(start: start, end: end)
    }

    /// `day` moved forward (or back) by whole days.
    static func shift(_ day: Date, byDays days: Int, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: days, to: day)
            ?? day.addingTimeInterval(Double(days) * 86400)
    }
}
