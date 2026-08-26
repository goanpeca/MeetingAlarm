import Foundation

/// Which backend a ``Meeting`` was read from.
enum SourceKind: String, Codable, Sendable {
    case eventKit
    case google
}

/// One meeting occurrence, normalized across calendar sources.
///
/// `id` is stable per occurrence so armed state survives re-syncs
/// (EventKit: event identifier + occurrence start; Google: event id + start).
struct Meeting: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let sourceKind: SourceKind
}
