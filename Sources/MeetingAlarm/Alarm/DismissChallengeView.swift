import SwiftUI

/// Renders the Dismiss control according to the configured challenge. Calls `onSolved`
/// only once the gate is cleared. Snooze/Join remain available elsewhere on the overlay.
struct DismissChallengeView: View {
    let challenge: DismissChallenge
    let onSolved: () -> Void

    @State private var expanded = false
    @State private var input = ""
    @State private var factorA = Int.random(in: 3 ... 9)
    @State private var factorB = Int.random(in: 3 ... 9)

    var body: some View {
        switch challenge {
        case .none:
            Button("Dismiss", role: .cancel) { onSolved() }
        case .hold:
            Button("Hold to dismiss") {}
                .onLongPressGesture(minimumDuration: 3) { onSolved() }
        case .math, .typePhrase:
            if expanded {
                gate
            } else {
                Button("Dismiss", role: .cancel) { expanded = true }
            }
        }
    }

    private var gate: some View {
        HStack(spacing: 8) {
            Text(prompt)
            TextField("", text: $input)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .onSubmit(check)
            Button("OK") { check() }
        }
    }

    private var prompt: String {
        switch challenge {
        case .math: "\(factorA) × \(factorB) = ?"
        case .typePhrase: "Type \(DismissChallenge.phrase):"
        default: ""
        }
    }

    private func check() {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        switch challenge {
        case .math where Int(trimmed) == factorA * factorB:
            onSolved()
        case .typePhrase where trimmed.uppercased() == DismissChallenge.phrase:
            onSolved()
        default:
            input = ""
        }
    }
}
