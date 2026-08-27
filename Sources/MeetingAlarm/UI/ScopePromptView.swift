import SwiftUI

/// In-popover modal asking whether a recurring action applies to one occurrence or the whole
/// series. Rendered inside the menu-bar window (not a system dialog) so its buttons are
/// actually clickable.
struct ScopePromptView: View {
    @ObservedObject var coordinator: AppCoordinator
    let prompt: ScopePrompt

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            VStack(spacing: 10) {
                Text("Recurring event").font(.headline)
                Text(prompt.meeting.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                choices
                Button("Cancel", role: .cancel) { dismiss() }
                    .frame(maxWidth: .infinity)
            }
            .padding(18)
            .frame(width: 280)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 24)
            .padding(20)
        }
    }

    @ViewBuilder
    private var choices: some View {
        switch prompt.kind {
        case .arm:
            action("Arm this event only", prominent: true) {
                coordinator.armOccurrence(prompt.meeting)
            }
            action("Arm all events in the series") { coordinator.armSeries(prompt.meeting) }
        case .disarm:
            action("Skip just this one", prominent: true) {
                coordinator.skipOccurrence(prompt.meeting)
            }
            action("Turn off the whole series", role: .destructive) {
                coordinator.disarmSeries(prompt.meeting)
            }
        }
    }

    @ViewBuilder
    private func action(
        _ title: String, prominent: Bool = false, role: ButtonRole? = nil,
        run: @escaping () -> Void
    ) -> some View {
        let button = Button(title, role: role) {
            run()
            dismiss()
        }
        .frame(maxWidth: .infinity)
        if prominent {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private func dismiss() {
        coordinator.scopePrompt = nil
    }
}
