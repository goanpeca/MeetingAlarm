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

    /// Disarm a whole series and drop its materialized occurrences and skips.
    func disarmSeries(_ seriesId: String) {
        armedSeries[seriesId] = nil
        seriesExceptions[seriesId] = nil
        armed = armed.filter { !($0.value.fromSeries && $0.value.meeting.seriesId == seriesId) }
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
