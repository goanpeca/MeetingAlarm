import SwiftUI

/// The puzzle gate shown before a gated action (Dismiss or Join) completes. Only used for
/// the non-`.none` challenges: `onSolved` runs the pending action, `onCancel` backs out.
struct ChallengeGateView: View {
    let challenge: DismissChallenge
    let onSolved: () -> Void
    let onCancel: () -> Void

    @State private var input = ""
    @State private var factorA = Int.random(in: 3 ... 9)
    @State private var factorB = Int.random(in: 3 ... 9)
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            switch challenge {
            case .hold:
                Text("Hold the button to confirm").font(.title3)
                Button("Hold…") {}
                    .buttonStyle(.borderedProminent)
                    .onLongPressGesture(minimumDuration: 3, perform: onSolved)
            case .math, .typePhrase:
                Text(prompt).font(.title2).bold()
                HStack(spacing: 8) {
                    TextField("", text: $input)
                        .textFieldStyle(.roundedBorder)
                        // The gate forces white text; the input sits on a system (light-in-
                        // light-mode) field, so its text must use the adaptive label color.
                        .foregroundStyle(.primary)
                        .frame(width: 160)
                        .focused($fieldFocused)
                        .onSubmit(check)
                    Button("OK") { check() }.buttonStyle(.borderedProminent)
                }
                .onAppear { fieldFocused = true }
            case .none:
                EmptyView()
            }
            Button("Cancel", role: .cancel) { onCancel() }
        }
        .padding(20)
        .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.white)
    }

    private var prompt: String {
        switch challenge {
        case .math: "\(factorA) × \(factorB) = ?"
        case .typePhrase: "Type \(DismissChallenge.phrase) to confirm"
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
