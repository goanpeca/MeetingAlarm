import SwiftUI

/// The MVP core: a chosen day's events (default today) with a checkbox each to arm a
/// reminder, plus a day navigator.
struct MenuContentView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var store: Store
    @State private var showFilter = false
    /// Scales the list's viewport with the user's Dynamic Type size so rows aren't clipped.
    @ScaledMetric private var rowHeight: CGFloat = 46

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
                            MeetingRow(coordinator: coordinator, store: store, meeting: meeting)
                        }
                    }
                }
                .frame(height: min(CGFloat(coordinator.meetings.count) * rowHeight + 8, 340))
            }
        }
        .padding(12)
        .frame(width: 360)
        .overlay {
            if let prompt = coordinator.scopePrompt {
                ScopePromptView(coordinator: coordinator, prompt: prompt)
            }
        }
        .task { await coordinator.sync() }
    }

    private var navigator: some View {
        HStack {
            Button { coordinator.prevDay() } label: { Image(systemName: "chevron.left") }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .accessibilityLabel("Previous day")
                .help("Previous day (⌘←)")
            Spacer()
            Button(dayLabel) { coordinator.today() }
                .font(.headline)
                .buttonStyle(.plain)
                .keyboardShortcut("t", modifiers: .command)
                .help("Jump to today (⌘T)")
            Spacer()
            Button { coordinator.nextDay() } label: { Image(systemName: "chevron.right") }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .accessibilityLabel("Next day")
                .help("Next day (⌘→)")
            Group {
                if coordinator.isRefreshing {
                    ProgressView().controlSize(.small).accessibilityLabel("Refreshing")
                } else {
                    Button { Task { await coordinator.refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .accessibilityLabel("Refresh")
                    .help("Refresh calendar (⌘R)")
                }
            }
            .frame(width: 20, height: 16) // fixed slot so the spinner swap doesn't shift icons
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
        .accessibilityLabel("Filter calendars")
        .help("Show or hide calendars")
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

    private func banner(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }
}
