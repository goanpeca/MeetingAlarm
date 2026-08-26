import Foundation

/// The seam that hides *which* calendar backend is active. Both `EventKitSource`
/// (macOS Calendar / Internet Accounts) and `GoogleCalendarSource` (direct Google
/// API) implement this, and the rest of the app depends only on the protocol so
/// the source can be switched in settings without touching callers.
///
/// Implementations are added per `docs/execution-plans/`.
///
/// `@MainActor`: sources are driven from the UI/coordinator and their async methods
/// await network/EventKit off the main thread without extra actor hops.
@MainActor
protocol CalendarSource {
    /// Which backend this source represents.
    var kind: SourceKind { get }

    /// Request access (EventKit permission, or Google OAuth sign-in). Throws if
    /// access is denied or sign-in fails.
    func authorize() async throws

    /// Fetch timed meetings that overlap `interval`, sorted by start time.
    func fetchUpcoming(within interval: DateInterval) async throws -> [Meeting]
}
