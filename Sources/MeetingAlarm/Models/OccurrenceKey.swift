import Foundation

/// A stable per-day key for a meeting occurrence. Using the day (not the exact start
/// time) keeps a meeting's identity — and its armed/checked state — stable when its time
/// is edited within the same day, while still disambiguating recurring occurrences across
/// different days.
enum OccurrenceKey {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func day(_ date: Date) -> String {
        formatter.string(from: date)
    }
}
