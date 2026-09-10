import Foundation

/// Recurring-series arming, split from `Store` to keep each file under the size limit.
/// Individual occurrences are materialized from these rules by `AppCoordinator`.
extension Store {
    /// Arm a whole recurring series with `preset`. Clears any prior per-occurrence skips.
    func armSeries(_ seriesId: String, preset: String) {
        armedSeries[seriesId] = preset
        seriesExceptions[seriesId] = nil
        save()
    }

    /// Disarm a whole series and drop its materialized occurrences, skips, and overrides.
    func disarmSeries(_ seriesId: String) {
        armedSeries[seriesId] = nil
        seriesExceptions[seriesId] = nil
        seriesOverrides[seriesId] = nil
        armed = armed.filter { !($0.value.fromSeries && $0.value.meeting.seriesId == seriesId) }
        save()
    }

    /// Set (or clear, when `isEmpty`) the color/sound override applied to a whole series.
    func setSeriesOverrides(_ seriesId: String, _ overrides: AlarmOverrides) {
        seriesOverrides[seriesId] = overrides.isEmpty ? nil : overrides
        save()
    }

    /// Skip a single occurrence of an armed series ("this event only").
    func addSeriesException(seriesId: String, occurrenceId: String) {
        seriesExceptions[seriesId, default: []].insert(occurrenceId)
        armed[occurrenceId] = nil
        save()
    }

    /// Replace all series-materialized entries with a freshly computed set, leaving
    /// explicitly-armed occurrences untouched. Returns true only when something changed
    /// (so callers can skip a needless reschedule).
    func setMaterializedSeries(_ entries: [SeriesMaterializer.Entry]) -> Bool {
        var next = armed.filter { !$0.value.fromSeries }
        for entry in entries {
            next[entry.meeting.id] = ArmedConfig(
                presetName: entry.preset, meeting: entry.meeting, fromSeries: true
            )
        }
        guard next != armed else { return false }
        armed = next
        save()
        return true
    }
}
