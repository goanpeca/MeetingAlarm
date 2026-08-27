import Foundation

/// Pure rule for which occurrences an armed series should schedule. Given the upcoming
/// occurrences inside the scheduling horizon and the current arming state, it returns the
/// occurrences to arm on behalf of their series — skipping explicit arms, per-occurrence
/// exceptions ("skip just this one"), and occurrences that already fired.
enum SeriesMaterializer {
    struct Entry: Equatable {
        let meeting: Meeting
        let preset: String
    }

    static func occurrencesToArm(
        upcoming: [Meeting],
        armedSeries: [String: String],
        exceptions: [String: Set<String>],
        explicitlyArmed: Set<String>,
        handled: Set<String>
    ) -> [Entry] {
        upcoming.compactMap { meeting in
            guard let seriesId = meeting.seriesId,
                  let preset = armedSeries[seriesId],
                  !(exceptions[seriesId]?.contains(meeting.id) ?? false),
                  !explicitlyArmed.contains(meeting.id),
                  !handled.contains(meeting.id)
            else { return nil }
            return Entry(meeting: meeting, preset: preset)
        }
    }
}
