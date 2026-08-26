import SwiftUI

/// Preferences: which calendar source is active, the default preset new arms use, and
/// the snooze intervals offered on the overlay.
struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var store: Store

    private let addableMinutes = [1, 2, 5, 10, 15, 30]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            picker("Calendar source", selection: Binding(
                get: { store.activeSource },
                set: { store.activeSource = $0 }
            )) {
                Text("macOS Calendar").tag(SourceKind.eventKit)
                Text("Google (direct)").tag(SourceKind.google)
            }

            picker("Default alarm", selection: Binding(
                get: { store.defaultPresetName },
                set: { store.defaultPresetName = $0 }
            )) {
                ForEach(SensoryProfile.presets, id: \.name) { preset in
                    Text(preset.name).tag(preset.name)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Snooze options").font(.headline)
                snoozeChips
            }
        }
        .padding(12)
        .frame(width: 340, alignment: .leading)
    }

    private func picker(
        _ title: String,
        selection: Binding<some Hashable>,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker(title, selection: selection, content: content)
                .labelsHidden()
                .frame(maxWidth: 180)
        }
    }

    private var snoozeChips: some View {
        let minutes = store.snoozeIntervals.map { Int($0 / 60) }.sorted()
        return VStack(alignment: .leading, spacing: 6) {
            if minutes.isEmpty {
                Text("None").foregroundStyle(.secondary).font(.caption)
            }
            ForEach(minutes, id: \.self) { minute in
                HStack {
                    Text("\(minute) min")
                    Spacer()
                    Button {
                        remove(minutes: minute)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            Menu("Add snooze option") {
                ForEach(addableMinutes, id: \.self) { minute in
                    Button("\(minute) min") { add(minutes: minute) }
                }
            }
            .frame(maxWidth: 180)
        }
    }

    private func add(minutes: Int) {
        let seconds = TimeInterval(minutes * 60)
        guard !store.snoozeIntervals.contains(seconds) else { return }
        store.snoozeIntervals = (store.snoozeIntervals + [seconds]).sorted()
    }

    private func remove(minutes: Int) {
        let seconds = TimeInterval(minutes * 60)
        store.snoozeIntervals.removeAll { $0 == seconds }
    }
}
