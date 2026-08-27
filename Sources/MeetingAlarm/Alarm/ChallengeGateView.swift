import SwiftUI

/// The puzzle gate shown before a gated action (Dismiss or Join) completes:
/// `onSolved` runs the pending action, `onCancel` backs out.
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
            case .math, .typePhrase:
                Text(prompt).font(.title2).bold()
                HStack(spacing: 8) {
                    TextField("", text: $input)
                        .textFieldStyle(.roundedBorder)
                        // Force a light field with black text: the overlay window renders in a
                        // dark appearance, so `.primary`/`.white` would be white-on-white here.
                        .environment(\.colorScheme, .light)
                        .foregroundStyle(.black)
                        .tint(.black)
                        .frame(width: 160)
                        .focused($fieldFocused)
                        .onSubmit(check)
                    Button("OK") { check() }.buttonStyle(.borderedProminent)
                }
                .onAppear {
                    // Give the (accessory-app) overlay window a beat to become key, then take
                    // focus and re-assert once, so typing works on the first click — no Cmd-Tab.
                    fieldFocused = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { fieldFocused = true }
                }
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
