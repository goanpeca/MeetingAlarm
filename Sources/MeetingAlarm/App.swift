import AppKit
import SwiftUI

/// Entry point. A menu-bar-only app (`LSUIElement` in Resources/Info.plist) — no
/// Dock icon. This is the scaffold shell: the meeting list, per-meeting arming,
/// and the alarm engine are wired in per `docs/execution-plans/`. Rich menu and
/// settings views belong to the UI layer (`Sources/MeetingAlarm/UI/`).
@main
struct MeetingAlarmApp: App {
    var body: some Scene {
        MenuBarExtra("Meeting Alarm", systemImage: "bell.badge") {
            MenuScaffoldView()
        }
        .menuBarExtraStyle(.window)
    }
}

/// Placeholder popover shown until calendar sync and alarms are implemented.
private struct MenuScaffoldView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meeting Alarm").font(.headline)
            Text("Scaffold — calendar sync and alarms are not wired up yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 260)
    }
}
