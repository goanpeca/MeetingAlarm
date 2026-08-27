import SwiftUI

/// The MVP core: a chosen day's events (default today) with a checkbox each to arm a
/// reminder, plus a day navigator.
struct MenuContentView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var store: Store
    @State private var showFilter = false

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
            if showFilter {
                calendarFilterList
                Divider()
            }
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
            if coordinator.isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Button { Task { await coordinator.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            calendarFilter
        }
        .buttonStyle(.borderless)
    }

    /// Funnel button that toggles the inline calendar filter panel.
    private var calendarFilter: some View {
        Button {
            showFilter.toggle()
        } label: {
            Image(systemName: showFilter
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
    }

    /// Inline, stays-open panel to show/hide calendars, grouped by source. Toggling a
    /// calendar keeps the panel open (unlike a Menu, which closes on each click).
    private var calendarFilterList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                if coordinator.availableCalendars.isEmpty {
                    Text("No calendars").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(groupedCalendars, id: \.source) { group in
                        Text(group.source.uppercased())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        ForEach(group.calendars) { cal in
                            Toggle(cal.title, isOn: Binding(
                                get: { coordinator.isCalendarShown(cal.id) },
                                set: { _ in coordinator.toggleCalendar(cal.id) }
                            ))
                            .toggleStyle(.checkbox)
                            .font(.callout)
                        }
                    }
                }
            }
        }
        .frame(height: min(CGFloat(coordinator.availableCalendars.count) * 26 + 44, 240))
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
            .disabled(coordinator.isPast(meeting))
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
