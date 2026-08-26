import SwiftUI

/// The MVP core: a chosen day's events (default today) with a checkbox each to arm a
/// reminder, plus a day navigator.
struct MenuContentView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var store: Store

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private var dayLabel: String {
        if Calendar.current.isDateInToday(coordinator.selectedDay) {
            return "Today"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: coordinator.selectedDay)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            navigator
            Divider()
            if coordinator.needsPermission {
                banner("Calendar access needed — enable it in System Settings › Privacy.")
            } else if let error = coordinator.errorMessage {
                banner(error)
            }
            if coordinator.meetings.isEmpty {
                Text("No events.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(coordinator.meetings) { meeting in
                            row(for: meeting)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(12)
        .frame(width: 340)
    }

    private var navigator: some View {
        HStack {
            Button { coordinator.prevDay() } label: { Image(systemName: "chevron.left") }
            Spacer()
            Button(dayLabel) { coordinator.today() }
                .font(.headline)
                .buttonStyle(.plain)
            Spacer()
            Button { coordinator.nextDay() } label: { Image(systemName: "chevron.right") }
        }
        .buttonStyle(.borderless)
    }

    private func row(for meeting: Meeting) -> some View {
        let armed = coordinator.isArmed(meeting)
        return HStack(alignment: .top, spacing: 8) {
            Toggle("", isOn: Binding(
                get: { coordinator.isArmed(meeting) },
                set: { _ in coordinator.toggleArm(meeting) }
            ))
            .labelsHidden()
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title).font(.body)
                HStack(spacing: 6) {
                    Text(Self.timeFormatter.string(from: meeting.start))
                    if coordinator.hasMultipleAccounts, let label = meeting.accountLabel {
                        Text("· \(label)").foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if armed {
                Picker("", selection: Binding(
                    get: { store.armed[meeting.id]?.presetName ?? store.defaultPresetName },
                    set: { coordinator.setPreset(meeting, preset: $0) }
                )) {
                    ForEach(SensoryProfile.presets, id: \.name) { preset in
                        Text(preset.name).tag(preset.name)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
            }
        }
        .padding(.vertical, 2)
    }

    private func banner(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }
}
