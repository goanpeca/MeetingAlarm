import Foundation

/// The calendar-visibility filter, split out to keep the main coordinator file focused
/// (and under the file-size limit).
extension AppCoordinator {
    // MARK: Calendar filter

    /// Whether events from a calendar are shown (i.e. it is not hidden).
    func isCalendarShown(_ id: String) -> Bool {
        !store.hiddenCalendarIds.contains(id)
    }

    /// Show/hide a calendar and re-fetch the day.
    func toggleCalendar(_ id: String) {
        if store.hiddenCalendarIds.contains(id) {
            store.hiddenCalendarIds.remove(id)
        } else {
            store.hiddenCalendarIds.insert(id)
        }
        source.hiddenCalendarIds = store.hiddenCalendarIds
        Task { await sync() }
    }
}
