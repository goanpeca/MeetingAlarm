import Foundation

/// Keeping armed occurrences in sync with the calendar: refreshing edited events and
/// materializing whole-series arms into schedulable occurrences. Split from the main
/// coordinator to stay under the file/type-size limits.
extension AppCoordinator {
    /// Update explicitly-armed occurrences whose underlying event changed (e.g. its time was
    /// edited), so the checked row shows the new time and the alarm re-times. Series-derived
    /// entries are left to `materializeSeries`, which rebuilds them from a fresh fetch.
    func reconcileArmed(_ latestMeetings: [Meeting]) {
        var changed = false
        for meeting in latestMeetings {
            if let config = store.armed[meeting.id], !config.fromSeries, config.meeting != meeting {
                store.updateArmed(meeting)
                changed = true
            }
        }
        if changed {
            reschedule()
        }
    }

    /// Rebuild explicit series rules from the rolling default-on scheduling horizon.
    func materializeSeries() {
        var entries: [SeriesMaterializer.Entry] = []
        if !store.armedSeries.isEmpty {
            entries = SeriesMaterializer.occurrencesToArm(
                upcoming: schedulingMeetings,
                armedSeries: store.armedSeries,
                exceptions: store.seriesExceptions,
                explicitlyArmed: Set(store.armed.filter { !$0.value.fromSeries }.keys),
                handled: store.handled
            )
        }
        _ = store.setMaterializedSeries(entries)
    }

    /// Combines stored custom arms with every fetched, non-excluded future meeting. The latter
    /// remain derived rather than persisted, so the saved state records only intentional choices.
    func activeArmedConfigs() -> [String: ArmedConfig] {
        var configs = store.armed
        for meeting in schedulingMeetings where isArmed(meeting) {
            if configs[meeting.id] == nil {
                configs[meeting.id] = ArmedConfig(
                    presetName: presetName(for: meeting), meeting: meeting
                )
            }
        }
        return configs.filter { isArmed($0.value.meeting) }
    }
}
