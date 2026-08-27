import Foundation

/// Per-meeting arming choice: which preset fires, plus a snapshot of the meeting so
/// the scheduler can fire it independent of the day currently shown in the list.
struct ArmedConfig: Codable, Sendable, Equatable {
    var presetName: String
    var meeting: Meeting
    /// True when this entry was materialized from an armed series (vs. armed on its own),
    /// so the coordinator can rebuild the series-derived entries without disturbing
    /// explicitly-armed occurrences.
    var fromSeries: Bool = false
}
