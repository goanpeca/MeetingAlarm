import Foundation

/// A user's explicit arm choice for one meeting: which preset fires, plus a snapshot of the
/// meeting. Persisted so a checked meeting keeps its preset across relaunches. Snapshots written
/// by older builds may carry extra keys (e.g. `fromSeries`); Codable ignores them on decode.
struct ArmedConfig: Codable, Sendable, Equatable {
    var presetName: String
    var meeting: Meeting
}
