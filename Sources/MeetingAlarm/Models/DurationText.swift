import Foundation

/// Formats a meeting's length as a short human string: "30 min", "1 hr", "1 hr 30 min".
enum DurationText {
    static func format(from start: Date, to end: Date) -> String {
        format(seconds: end.timeIntervalSince(start))
    }

    static func format(seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int((seconds / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        switch (hours, minutes) {
        case (0, _): return "\(minutes) min"
        case (_, 0): return "\(hours) hr"
        default: return "\(hours) hr \(minutes) min"
        }
    }
}
