import Foundation

/// An optional gate on the Dismiss button, so an alarm can't be cleared mindlessly.
/// Snooze and Join stay available, so the user is never fully trapped.
enum DismissChallenge: String, Codable, Sendable, CaseIterable {
    /// Dismiss immediately (default).
    case none
    /// Press and hold the button for a few seconds.
    case hold
    /// Solve a small multiplication problem.
    case math
    /// Type a confirmation word.
    case typePhrase

    var displayName: String {
        switch self {
        case .none: "Off (one click)"
        case .hold: "Press & hold"
        case .math: "Solve math"
        case .typePhrase: "Type a word"
        }
    }

    /// The word to type for `.typePhrase`.
    static let phrase = "DISMISS"
}
