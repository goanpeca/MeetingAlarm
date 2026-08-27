import Foundation

/// The gate on the Dismiss button, so an alarm can't be cleared mindlessly. Esc always
/// dismisses regardless, and Snooze/Join stay available, so the user is never trapped.
enum DismissChallenge: String, Codable, Sendable, CaseIterable {
    /// Solve a small multiplication problem (default).
    case math
    /// Type a confirmation word.
    case typePhrase

    var displayName: String {
        switch self {
        case .math: "Solve math"
        case .typePhrase: "Type a word"
        }
    }

    /// The word to type for `.typePhrase`.
    static let phrase = "DISMISS"
}
