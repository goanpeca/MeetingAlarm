import AppKit
import SwiftUI

/// Menu-bar-only app (`LSUIElement` in Resources/Info.plist) — no Dock icon.
@main
struct MeetingAlarmApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra("Meeting Alarm", systemImage: "bell.badge") {
            RootView(coordinator: coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Container: a pane switch above the active view, with a shared footer.
struct RootView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var pane: Pane = .meetings

    enum Pane: String, CaseIterable, Identifiable {
        case meetings = "Meetings"
        case settings = "Settings"
        case accounts = "Accounts"
        var id: String {
            rawValue
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $pane) {
                ForEach(Pane.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.top, .horizontal], 12)

            switch pane {
            case .meetings:
                MenuContentView(coordinator: coordinator, store: coordinator.store)
            case .settings:
                SettingsView(coordinator: coordinator, store: coordinator.store)
            case .accounts:
                AccountsView(coordinator: coordinator, accounts: coordinator.accounts)
            }

            Divider()
            HStack {
                Button("Test Alarm") { coordinator.testAlarm() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .padding([.bottom, .horizontal], 12)
        }
        .frame(width: 340)
    }
}
