import Foundation

/// Keeping armed occurrences in sync with the calendar: refreshing edited events and
/// materializing whole-series arms into schedulable occurrences. Split from the main
/// coordinator to stay under the file/type-size limits.
extension AppCoordinator {
    /// Update explicitly-armed occurrences whose underlying event changed (e.g. its time was
    /// edited), so the checked row shows the new time and the alarm re-times. Series-derived
    /// entries are left to `materializeSeries`, which rebuilds them from a fresh fetch.
    func reconcileArmed() {
        var changed = false
        for meeting in meetings {
            if let config = store.armed[meeting.id], !config.fromSeries, config.meeting != meeting {
                store.updateArmed(meeting)
                changed = true
            }
        }
        if changed {
            reschedule()
        }
    }

    /// Rebuild the series-armed occurrences within the scheduling horizon so a whole armed
    /// series fires day-to-day. Throttled: the extra horizon fetch runs at most every 2
    /// minutes on the poll, but an arm/disarm action passes `force` to run it now.
    func materializeSeries(force: Bool = false) async {
        var entries: [SeriesMaterializer.Entry] = []
        if !store.armedSeries.isEmpty {
            if !force, Date().timeIntervalSince(lastSeriesMaterialize) < 120 {
                return
            }
            lastSeriesMaterialize = Date()
            let horizon = DateInterval(start: Date(), duration: seriesHorizon)
            let upcoming = await (try? source.fetchUpcoming(within: horizon)) ?? []
            entries = SeriesMaterializer.occurrencesToArm(
                upcoming: upcoming,
                armedSeries: store.armedSeries,
                exceptions: store.seriesExceptions,
                explicitlyArmed: Set(store.armed.filter { !$0.value.fromSeries }.keys),
                handled: store.handled
            )
        }
        if store.setMaterializedSeries(entries) {
            reschedule()
        }
    }
}
