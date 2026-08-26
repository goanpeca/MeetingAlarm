import Foundation

/// Per-meeting arming choice: which preset fires, plus a snapshot of the meeting so
/// the scheduler can fire it independent of the day currently shown in the list.
struct ArmedConfig: Codable, Sendable, Equatable {
    var presetName: String
    var meeting: Meeting
}
