import SwiftUI

/// One meeting in the day list: an arm checkbox, the title, time + duration, a `>`
/// disclosure that reveals attendees + full description, and (when armed) a preset picker.
struct MeetingRow: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var store: Store
    let meeting: Meeting

    @State private var isExpanded = false

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private var hasDetail: Bool {
        !meeting.attendees.isEmpty || !(meeting.notes ?? "").isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            if isExpanded, hasDetail {
                MeetingDetailView(meeting: meeting).padding(.leading, 26)
            }
        }
        .padding(.vertical, 2)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 6) {
            Toggle("", isOn: Binding(
                get: { coordinator.isArmed(meeting) },
                set: { _ in coordinator.toggleArm(meeting) }
            ))
            .labelsHidden()
            .disabled(coordinator.isPast(meeting))
            disclosure
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title).font(.body)
                subtitle
            }
            Spacer()
            if coordinator.isArmed(meeting) {
                presetPicker
            }
        }
    }

    /// A chevron that expands the row. Rows with nothing to show still reserve its width so
    /// every title lines up.
    @ViewBuilder
    private var disclosure: some View {
        let chevron = Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 12)
            .padding(.top, 3)
        if hasDetail {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                chevron.rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .buttonStyle(.plain)
        } else {
            chevron.opacity(0)
        }
    }

    private var subtitle: some View {
        HStack(spacing: 6) {
            Text(Self.timeFormatter.string(from: meeting.start))
            Text("· \(DurationText.format(from: meeting.start, to: meeting.end))")
            if let label = meeting.accountLabel {
                Text("· \(label)").lineLimit(1)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var presetPicker: some View {
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
