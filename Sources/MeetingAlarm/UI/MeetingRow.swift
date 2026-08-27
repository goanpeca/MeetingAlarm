import SwiftUI

/// One meeting in the day list: an arm checkbox, the title, time + duration, a `>`
/// disclosure that reveals attendees + full description, and (when armed) a preset picker.
struct MeetingRow: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var store: Store
    let meeting: Meeting
    /// Whether to show the per-row account label. Hidden when the whole day belongs to a
    /// single account, where repeating the same email on every row is just noise.
    var showAccount: Bool = true

    @State private var isExpanded = false
    @State private var showOverrides = false

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
                set: { _ in coordinator.requestArmToggle(meeting) }
            ))
            .labelsHidden()
            .disabled(coordinator.isPast(meeting))
            .accessibilityLabel("Arm alarm for \(meeting.title)")
            disclosure
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title).font(.body)
                subtitle
            }
            Spacer()
            if coordinator.isArmed(meeting) {
                overrideButton
            }
        }
    }

    /// Gear that opens a popover to customize this meeting's alarm (color/sound), overriding
    /// the global settings. Replaces the old per-row preset picker.
    private var overrideButton: some View {
        Button {
            showOverrides.toggle()
        } label: {
            Image(systemName: coordinator.overrides(for: meeting).isEmpty
                ? "gearshape" : "gearshape.fill")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Customize alarm for \(meeting.title)")
        .help("Customize this alarm's color and sound")
        .popover(isPresented: $showOverrides, arrowEdge: .bottom) {
            MeetingOverridesView(coordinator: coordinator, store: store, meeting: meeting)
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
            .accessibilityLabel(isExpanded ? "Hide details" : "Show details")
            .help(isExpanded ? "Hide details" : "Show attendees and description")
        } else {
            chevron.opacity(0).accessibilityHidden(true)
        }
    }

    private var subtitle: some View {
        HStack(spacing: 6) {
            Text(Self.timeFormatter.string(from: meeting.start))
            Text("· \(DurationText.format(from: meeting.start, to: meeting.end))")
            if coordinator.isRecurring(meeting) {
                Text("· Repeats")
            }
            if showAccount, let label = meeting.accountLabel {
                Text("· \(label)").lineLimit(1)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
