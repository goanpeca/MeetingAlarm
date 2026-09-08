import Foundation

/// Recurring-series arming, split from `Store` to keep each file under the size limit.
/// Individual occurrences are materialized from these rules by `AppCoordinator`.
extension Store {
    /// Arm a whole recurring series with `preset`. Clears any prior per-occurrence skips.
    func armSeries(_ seriesId: String, preset: String) {
        armedSeries[seriesId] = preset
        seriesExceptions[seriesId] = nil
        excludedSeriesIds.remove(seriesId)
        save()
    }

    /// Opt out of a whole series and drop its materialized/explicit occurrences, skips, and
    /// overrides.
    func disarmSeries(_ seriesId: String) {
        excludedSeriesIds.insert(seriesId)
        armedSeries[seriesId] = nil
        seriesExceptions[seriesId] = nil
        seriesOverrides[seriesId] = nil
        let occurrenceIds = armed.compactMap { id, config in
            config.meeting.seriesId == seriesId ? id : nil
        }
        armed = armed.filter { $0.value.meeting.seriesId != seriesId }
        for id in occurrenceIds {
            snoozes[id] = nil
            armOverrides[id] = nil
            handled.remove(id)
        }
        save()
    }

    /// Set (or clear, when `isEmpty`) the color/sound override applied to a whole series.
    func setSeriesOverrides(_ seriesId: String, _ overrides: AlarmOverrides) {
        seriesOverrides[seriesId] = overrides.isEmpty ? nil : overrides
        save()
    }

    /// Skip a single occurrence of an armed series ("this event only"). This also serves
    /// default-on arming, where no explicit series rule exists.
    func addSeriesException(seriesId: String, occurrenceId: String) {
        seriesExceptions[seriesId, default: []].insert(occurrenceId)
        exclude(occurrenceId)
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
