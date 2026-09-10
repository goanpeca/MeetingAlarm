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

    /// Whether the rolling horizon is needed at all: only auto-arm or an explicitly-armed
    /// series schedules meetings beyond the day currently on screen.
    var needsHorizon: Bool {
        store.autoArm || !store.armedSeries.isEmpty
    }

    /// Refresh the 60-day scheduling horizon — but only when it's actually needed, and (unless
    /// `force`d) at most every `horizonThrottle` seconds, so the frequent day-list poll doesn't
    /// run a full main-actor EventKit query every time. When it isn't needed, the horizon is
    /// dropped so stale derived arms can't linger.
    func refreshHorizon(force: Bool) async {
        guard needsHorizon else {
            schedulingMeetings = []
            return
        }
        if !force, Date().timeIntervalSince(lastHorizonFetch) < horizonThrottle {
            return
        }
        lastHorizonFetch = Date()
        let horizon = DateInterval(
            start: calendar.startOfDay(for: Date()),
            end: Date().addingTimeInterval(schedulingHorizon)
        )
        if let upcoming = try? await source.fetchUpcoming(within: horizon) {
            schedulingMeetings = upcoming
        }
    }

    /// Combines stored custom arms with every fetched, non-excluded future meeting (when
    /// auto-arm is on). Derived arms remain unpersisted, so saved state records only intentional
    /// choices — and they only cover meetings that haven't started, so enabling auto-arm or
    /// waking mid-day never full-screens you for a meeting you're already in. Explicit arms keep
    /// their overdue-fire safety net. The arming sets are built once per pass, not per meeting,
    /// so scheduling stays linear in the horizon size.
    func activeArmedConfigs() -> [String: ArmedConfig] {
        let explicitIds = Set(store.armed.filter { !$0.value.fromSeries }.keys)
        let armedSeriesIds = Set(store.armedSeries.keys)
        let now = Date()
        func armed(_ meeting: Meeting) -> Bool {
            DefaultArming.isArmed(
                meeting: meeting, autoArm: store.autoArm,
                explicitlyArmedIds: explicitIds, armedSeriesIds: armedSeriesIds,
                excludedMeetingIds: store.excludedMeetingIds,
                excludedSeriesIds: store.excludedSeriesIds,
                seriesExceptions: store.seriesExceptions
            )
        }
        var configs = store.armed
        for meeting in schedulingMeetings where armed(meeting) {
            if configs[meeting.id] == nil, meeting.start > now {
                configs[meeting.id] = ArmedConfig(
                    presetName: presetName(for: meeting), meeting: meeting
                )
            }
        }
        return configs.filter { armed($0.value.meeting) }
    }
}
