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
    /// Owning account/calendar label (e.g. an email), shown when >1 account is present.
    let accountLabel: String?
    /// Video/join links found for the meeting — one Join button each (e.g. Meet AND Zoom
    /// if both were pasted on the event by mistake, so you can pick the right one).
    let joinURLs: [URL]

    init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        sourceKind: SourceKind,
        accountLabel: String?,
        joinURLs: [URL] = []
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.sourceKind = sourceKind
        self.accountLabel = accountLabel
        self.joinURLs = joinURLs
    }
}
