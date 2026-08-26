import Foundation

/// Pure mapping from EventKit event fields to `Meeting`, isolated from `EKEventStore`
/// so it is unit-testable (an `EKEvent` cannot be constructed in tests).
enum EventKitMapper {
    static func meeting(
        identifier: String,
        title: String?,
        start: Date,
        end: Date,
        isAllDay: Bool,
        calendarTitle: String,
        occurrenceStart: Date
    ) -> Meeting? {
        guard !isAllDay else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let resolvedTitle = title.flatMap { $0.isEmpty ? nil : $0 } ?? "(No title)"
        return Meeting(
            id: "eventkit:\(identifier):\(formatter.string(from: occurrenceStart))",
            title: resolvedTitle,
            start: start,
            end: end,
            sourceKind: .eventKit,
            accountLabel: calendarTitle
        )
    }
}
