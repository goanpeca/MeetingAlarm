import SwiftUI

/// Asks whether flipping the auto-arm setting should also reset every per-meeting arm/skip
/// choice, so all future meetings follow the new default. Shown as an in-popover overlay — a
/// system dialog's buttons aren't clickable inside a `MenuBarExtra(.window)`.
struct AutoArmPromptView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var store: Store

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            VStack(spacing: 10) {
                Text(store.autoArm ? "Arm all future meetings?" : "Unarm all future meetings?")
                    .font(.headline)
                Text(store.autoArm
                    ? "Turn alarms on for every future meeting, clearing the ones you unchecked."
                    : "Turn alarms off for every future meeting, clearing the ones you checked.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button(store.autoArm ? "Arm all" : "Unarm all") {
                    coordinator.applyAutoArmToAll()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .frame(maxWidth: .infinity)
                Button("Keep my choices", role: .cancel) { dismiss() }
                    .frame(maxWidth: .infinity)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(18)
            .frame(width: 280)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 24)
            .padding(20)
        }
    }

    private func dismiss() {
        coordinator.showAutoArmPrompt = false
    }
}
