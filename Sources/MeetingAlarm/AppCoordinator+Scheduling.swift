import Foundation

/// Builds the set of alarms to arm right now from the rolling upcoming-meetings window, applying
/// the arming policy. Split from the main coordinator to stay under the file/type-size limits.
extension AppCoordinator {
    /// Every meeting in the current window that should fire, as `id -> config`. The arming sets
    /// are built once (not per meeting), so this stays linear in the window size. Derived
    /// (auto-arm default) alarms skip meetings already in progress — waking mid-day never
    /// full-screens you for a meeting you're already in — while explicit arms and armed series
    /// keep their overdue-fire safety net.
    func activeArmedConfigs() -> [String: ArmedConfig] {
        let explicitIds = Set(store.armed.keys)
        let armedSeriesIds = Set(store.armedSeries.keys)
        let now = Date()
        var configs: [String: ArmedConfig] = [:]
        for meeting in upcomingMeetings {
            let armed = DefaultArming.isArmed(
                meeting: meeting, autoArm: store.autoArm,
                explicitlyArmedIds: explicitIds, armedSeriesIds: armedSeriesIds,
                excludedMeetingIds: store.excludedMeetingIds,
                excludedSeriesIds: store.excludedSeriesIds,
                seriesExceptions: store.seriesExceptions
            )
            guard armed else { continue }
            let isExplicit = explicitIds.contains(meeting.id)
                || (meeting.seriesId.map(armedSeriesIds.contains) ?? false)
            if !isExplicit, meeting.start <= now {
                continue
            }
            configs[meeting.id] = ArmedConfig(
                presetName: presetName(for: meeting), meeting: meeting
            )
        }
        return configs
    }
}
