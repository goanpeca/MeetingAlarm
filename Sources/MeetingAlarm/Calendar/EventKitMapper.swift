import Foundation

/// Pure mapping from EventKit event fields to `Meeting`, isolated from `EKEventStore`
/// so it is unit-testable (an `EKEvent` cannot be constructed in tests).
enum EventKitMapper {
    /// The subset of `EKEvent` fields the mapper needs (bundled to keep the call small).
    struct Fields {
        let identifier: String
        let title: String?
        let start: Date
        let end: Date
        let isAllDay: Bool
        let calendarTitle: String
        let occurrenceStart: Date
        let url: URL?
        let notes: String?
        let location: String?
        let attendees: [String]
    }

    static func meeting(_ fields: Fields) -> Meeting? {
        guard !fields.isAllDay else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let resolvedTitle = fields.title.flatMap { $0.isEmpty ? nil : $0 } ?? "(No title)"
        let joinURLs = MeetingLink.detectAll(
            explicit: fields.url,
            texts: [fields.location, fields.notes]
        )
        return Meeting(
            id: "eventkit:\(fields.identifier):\(formatter.string(from: fields.occurrenceStart))",
            title: resolvedTitle,
            start: fields.start,
            end: fields.end,
            sourceKind: .eventKit,
            accountLabel: fields.calendarTitle,
            joinURLs: joinURLs,
            notes: fields.notes,
            attendees: fields.attendees
        )
    }
}
