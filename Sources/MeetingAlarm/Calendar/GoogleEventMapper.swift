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
        let hangoutLink: String?
        let location: String?
        let description: String?
        let conferenceData: ConferenceData?
    }

    private struct When: Decodable {
        let dateTime: String?
        let date: String?
    }

    private struct ConferenceData: Decodable {
        let entryPoints: [EntryPoint]?
    }

    private struct EntryPoint: Decodable {
        let uri: String?
        let entryPointType: String?
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
                accountLabel: accountLabel,
                joinURL: joinURL(for: item)
            )
        }
    }

    private static func joinURL(for item: Item) -> URL? {
        let videoEntry = item.conferenceData?.entryPoints?
            .first { $0.entryPointType == "video" }?.uri
        let explicit = item.hangoutLink.flatMap(URL.init(string:))
            ?? videoEntry.flatMap(URL.init(string:))
        return MeetingLink.detect(explicit: explicit, texts: [item.location, item.description])
    }
}
