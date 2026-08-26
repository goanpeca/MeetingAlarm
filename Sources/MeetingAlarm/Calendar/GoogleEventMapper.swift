import Foundation

/// Pure decode of the Google Calendar `events.list` response into `[Meeting]`.
/// Timed events only (an all-day event has `start.date` but no `start.dateTime`).
enum GoogleEventMapper {
    private struct Response: Decodable { let items: [Item]? }

    private struct Item: Decodable {
        let id: String
        let summary: String?
        let start: When
        let end: When
    }

    private struct When: Decodable {
        let dateTime: String?
        let date: String?
    }

    static func meetings(
        fromEventsJSON data: Data,
        accountId: String,
        accountLabel: String
    ) throws -> [Meeting] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return (response.items ?? []).compactMap { item in
            guard let startISO = item.start.dateTime,
                  let endISO = item.end.dateTime,
                  let start = formatter.date(from: startISO),
                  let end = formatter.date(from: endISO)
            else { return nil } // skip all-day / unparseable
            let title = item.summary.flatMap { $0.isEmpty ? nil : $0 } ?? "(No title)"
            return Meeting(
                id: "google:\(accountId):\(item.id):\(startISO)",
                title: title,
                start: start,
                end: end,
                sourceKind: .google,
                accountLabel: accountLabel
            )
        }
    }
}
