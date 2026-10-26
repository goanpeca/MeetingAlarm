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

    /// Whether `input` solves this challenge. `factorA`/`factorB` are the operands shown for
    /// `.math` (ignored for `.typePhrase`). Surrounding spaces are ignored; the phrase match is
    /// case-insensitive.
    func isSolved(input: String, factorA: Int = 0, factorB: Int = 0) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        switch self {
        case .math: return Int(trimmed) == factorA * factorB
        case .typePhrase: return trimmed.uppercased() == Self.phrase
        }
    }
}
