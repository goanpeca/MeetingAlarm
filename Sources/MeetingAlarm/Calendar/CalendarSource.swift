import Foundation

/// The seam that hides *which* calendar backend is active. `EventKitSource`
/// (macOS Calendar / Internet Accounts) implements this, and the rest of the app
/// depends only on the protocol so another backend can be added later without
/// touching callers.
///
/// `@MainActor`: sources are driven from the UI/coordinator and their async methods
/// await network/EventKit off the main thread without extra actor hops.
@MainActor
protocol CalendarSource {
    /// Which backend this source represents.
    var kind: SourceKind { get }

    /// Invoked when the underlying calendar data changes (e.g. an EventKit sync pulls new
    /// events), so the owner can re-fetch immediately instead of waiting for the next poll.
    var onChange: (() -> Void)? { get set }

    /// Calendar ids the user has hidden; events from these are excluded from fetches.
    var hiddenCalendarIds: Set<String> { get set }

    /// Request access (the EventKit calendar permission). Throws if access is denied.
    func authorize() async throws

    /// The calendars this source can show, for the filter UI.
    func availableCalendars() async -> [CalendarInfo]

    /// Ask the backend to pull the latest from the server (e.g. EventKit refetches Google),
    /// so newly-created events show without waiting for the OS's periodic sync.
    func refresh() async

    /// Fetch timed meetings that overlap `interval`, sorted by start time.
    func fetchUpcoming(within interval: DateInterval) async throws -> [Meeting]
}
