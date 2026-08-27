import EventKit
import Foundation

enum CalendarError: LocalizedError {
    case accessDenied
    case notConfigured(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied: "Calendar access was denied. Enable it in System Settings › Privacy."
        case let .notConfigured(detail): detail
        }
    }
}

/// Reads timed events from the macOS Calendar database, which already aggregates every
/// Google/iCloud/Exchange account added in System Settings › Internet Accounts.
@MainActor
final class EventKitSource: CalendarSource {
    let kind: SourceKind = .eventKit
    var onChange: (() -> Void)?

    private let store = EKEventStore()

    init() {
        // Fire `onChange` whenever the calendar DB changes (a fresh account sync, an
        // edited/added/removed event) so the list refreshes immediately.
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onChange?() }
        }
    }

    func authorize() async throws {
        let granted = try await store.requestFullAccessToEvents()
        if !granted {
            throw CalendarError.accessDenied
        }
    }

    func fetchUpcoming(within interval: DateInterval) async throws -> [Meeting] {
        let predicate = store.predicateForEvents(
            withStart: interval.start,
            end: interval.end,
            calendars: nil
        )
        return store.events(matching: predicate).compactMap { event in
            EventKitMapper.meeting(.init(
                identifier: event.eventIdentifier ?? UUID().uuidString,
                title: event.title,
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                calendarTitle: event.calendar.title,
                occurrenceStart: event.startDate,
                url: event.url,
                notes: event.notes,
                location: event.location
            ))
        }
        .sorted { $0.start < $1.start }
    }
}
