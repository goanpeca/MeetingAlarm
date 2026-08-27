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

    init(presetName: String, meeting: Meeting, fromSeries: Bool = false) {
        self.presetName = presetName
        self.meeting = meeting
        self.fromSeries = fromSeries
    }

    init(from decoder: any Decoder) throws {
        // Snapshots written before `fromSeries` existed lack the key; Swift's synthesized
        // Decodable ignores the property default and would throw, dropping the whole saved
        // snapshot (all armed meetings + settings). Decode it defensively instead.
        let container = try decoder.container(keyedBy: CodingKeys.self)
        presetName = try container.decode(String.self, forKey: .presetName)
        meeting = try container.decode(Meeting.self, forKey: .meeting)
        fromSeries = try container.decodeIfPresent(Bool.self, forKey: .fromSeries) ?? false
    }
}
