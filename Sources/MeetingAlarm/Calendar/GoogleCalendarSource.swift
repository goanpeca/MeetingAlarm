import Foundation

/// Reads events straight from Google across every connected account, merging the
/// per-account results. A failing account is logged and skipped, not fatal.
@MainActor
final class GoogleCalendarSource: CalendarSource {
    let kind: SourceKind = .google
    var onChange: (() -> Void)?
    var hiddenCalendarIds: Set<String> = []

    private let auth: GoogleAuth
    private let accounts: GoogleAccountStore
    private let log = Log.make("google-source")

    init(auth: GoogleAuth, accounts: GoogleAccountStore) {
        self.auth = auth
        self.accounts = accounts
    }

    func authorize() async throws {
        guard !accounts.accounts.isEmpty else {
            throw CalendarError.notConfigured("Add a Google account in the Accounts tab.")
        }
    }

    func availableCalendars() async -> [CalendarInfo] {
        accounts.accounts.map {
            CalendarInfo(id: $0.id, title: $0.email, sourceTitle: "Google")
        }
    }

    func fetchUpcoming(within interval: DateInterval) async throws -> [Meeting] {
        var groups: [[Meeting]] = []
        for account in accounts.accounts where !hiddenCalendarIds.contains(account.id) {
            do {
                let token = try await auth.accessToken(for: account.id)
                let data = try await fetchEvents(token: token, interval: interval)
                try groups.append(GoogleEventMapper.meetings(
                    fromEventsJSON: data, accountId: account.id, accountLabel: account.email
                ))
            } catch {
                log.error("account \(account.email, privacy: .public) fetch failed")
            }
        }
        return MeetingMerge.merged(groups)
    }

    private func fetchEvents(token: String, interval: DateInterval) async throws -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "www.googleapis.com"
        comps.path = "/calendar/v3/calendars/primary/events"
        comps.queryItems = [
            .init(name: "timeMin", value: formatter.string(from: interval.start)),
            .init(name: "timeMax", value: formatter.string(from: interval.end)),
            .init(name: "singleEvents", value: "true"),
            .init(name: "orderBy", value: "startTime")
        ]
        guard let url = comps.url else {
            throw CalendarError.notConfigured("Could not build the Google Calendar URL.")
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200 ..< 300).contains(http.statusCode) else {
            throw CalendarError.notConfigured("Google Calendar request failed.")
        }
        return data
    }
}
