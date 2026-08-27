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
                .frame(height: min(CGFloat(coordinator.meetings.count) * 46 + 8, 320))
            }
        }
        .padding(12)
        .frame(width: 340)
        .task { await coordinator.sync() }
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
            calendarFilter
        }
        .buttonStyle(.borderless)
    }

    /// A funnel menu to show/hide calendars, grouped by their source so you can see where
    /// each one (e.g. a subscribed gym schedule) actually comes from.
    private var calendarFilter: some View {
        Menu {
            if coordinator.availableCalendars.isEmpty {
                Text("No calendars")
            } else {
                ForEach(groupedCalendars, id: \.source) { group in
                    Section(group.source) {
                        ForEach(group.calendars) { cal in
                            Toggle(cal.title, isOn: Binding(
                                get: { coordinator.isCalendarShown(cal.id) },
                                set: { _ in coordinator.toggleCalendar(cal.id) }
                            ))
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var groupedCalendars: [(source: String, calendars: [CalendarInfo])] {
        Dictionary(grouping: coordinator.availableCalendars, by: \.sourceTitle)
            .map { (source: $0.key, calendars: $0.value.sorted { $0.title < $1.title }) }
            .sorted { $0.source < $1.source }
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
                    if let label = meeting.accountLabel {
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
