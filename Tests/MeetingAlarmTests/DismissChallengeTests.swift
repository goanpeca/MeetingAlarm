import Foundation
@testable import MeetingAlarm
import Testing

@Suite("DismissChallenge")
struct DismissChallengeTests {
    @Test("math: only the exact product solves it; surrounding spaces are ignored")
    func mathSolved() {
        #expect(DismissChallenge.math.isSolved(input: "42", factorA: 6, factorB: 7))
        #expect(DismissChallenge.math.isSolved(input: "  42 ", factorA: 6, factorB: 7))
        #expect(!DismissChallenge.math.isSolved(input: "41", factorA: 6, factorB: 7))
        #expect(!DismissChallenge.math.isSolved(input: "13", factorA: 6, factorB: 7)) // the sum
        #expect(!DismissChallenge.math.isSolved(input: "", factorA: 6, factorB: 7))
        #expect(!DismissChallenge.math.isSolved(input: "forty-two", factorA: 6, factorB: 7))
    }

    @Test("typePhrase: matches the phrase case-insensitively and trims spaces")
    func phraseSolved() {
        #expect(DismissChallenge.typePhrase.isSolved(input: "DISMISS"))
        #expect(DismissChallenge.typePhrase.isSolved(input: "dismiss"))
        #expect(DismissChallenge.typePhrase.isSolved(input: "  Dismiss "))
        #expect(!DismissChallenge.typePhrase.isSolved(input: "dismis"))
        #expect(!DismissChallenge.typePhrase.isSolved(input: ""))
    }

    @Test("typePhrase ignores the math operands, and math ignores the phrase")
    func challengesAreIndependent() {
        #expect(DismissChallenge.typePhrase.isSolved(input: "dismiss", factorA: 3, factorB: 3))
        #expect(!DismissChallenge.math.isSolved(input: "DISMISS", factorA: 3, factorB: 3))
    }

    @Test("Each challenge has a distinct display name")
    func displayNames() {
        let names = DismissChallenge.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
        #expect(DismissChallenge.math.displayName == "Solve math")
        #expect(DismissChallenge.typePhrase.displayName == "Type a word")
    }
}
