import AppKit
import SwiftUI

/// Preferences, laid out as a grouped `Form` so labels and controls align cleanly.
struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var store: Store

    private let addableMinutes = [1, 2, 5, 10, 15, 30]

    var body: some View {
        Form {
            Picker("Default alarm", selection: bind(\.defaultPresetName)) {
                ForEach(SensoryProfile.presets, id: \.name) { Text($0.name).tag($0.name) }
            }
            Picker("Start alarm", selection: bind(\.leadTimeMinutes)) {
                ForEach([0, 1, 2, 3, 5, 10, 15, 30], id: \.self) { minutes in
                    Text(minutes == 0 ? "At meeting time" : "\(minutes) min before").tag(minutes)
                }
            }

            Section("Sound") {
                Toggle("Play sound", isOn: bind(\.soundEnabled))
                Picker("Sound", selection: bind(\.alarmSound)) {
                    ForEach(SoundChoice.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .disabled(!store.soundEnabled)
                Toggle("Repeat until dismissed", isOn: bind(\.soundRepeat))
                    .disabled(!store.soundEnabled)
                Picker("Gap between repeats", selection: bind(\.soundGapSeconds)) {
                    ForEach([0.0, 1, 2, 3, 5], id: \.self) { seconds in
                        Text(seconds == 0 ? "None" : "\(Int(seconds))s").tag(seconds)
                    }
                }
                .disabled(!store.soundEnabled || !store.soundRepeat)
                LabeledContent("Volume") {
                    Slider(value: bind(\.alarmVolume), in: 0 ... 1)
                }
                .disabled(!store.soundEnabled)
                Button(coordinator.isPreviewingSound ? "Stop sound" : "Play sample") {
                    coordinator.togglePreview()
                }
                .disabled(!store.soundEnabled)
            }

            Section("Appearance") {
                Picker("Effect", selection: bind(\.alarmEffect)) {
                    ForEach(Effect.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                ColorPicker("Alarm color", selection: colorBinding, supportsOpacity: false)
                Picker("Dismiss", selection: bind(\.dismissChallenge)) {
                    ForEach(DismissChallenge.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }

            Section("Snooze options") { snoozeRows }
        }
        .formStyle(.grouped)
        .frame(width: 340, height: 470)
    }

    // MARK: Bindings

    private func bind<Value>(_ keyPath: ReferenceWritableKeyPath<Store, Value>) -> Binding<Value> {
        Binding(get: { store[keyPath: keyPath] }, set: { store[keyPath: keyPath] = $0 })
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: {
                Color(
                    .sRGB,
                    red: store.alarmColor.red,
                    green: store.alarmColor.green,
                    blue: store.alarmColor.blue,
                    opacity: 1
                )
            },
            set: { newColor in
                let converted = NSColor(newColor).usingColorSpace(.sRGB) ?? .red
                store.alarmColor = RGBAColor(
                    red: Double(converted.redComponent),
                    green: Double(converted.greenComponent),
                    blue: Double(converted.blueComponent),
                    alpha: 1
                )
            }
        )
    }

    // MARK: Snooze editor

    @ViewBuilder
    private var snoozeRows: some View {
        let minutes = store.snoozeIntervals.map { Int($0 / 60) }.sorted()
        ForEach(minutes, id: \.self) { minute in
            HStack {
                Text("\(minute) min")
                Spacer()
                Button { remove(minutes: minute) } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless)
            }
        }
        Menu("Add snooze option") {
            ForEach(addableMinutes, id: \.self) { minute in
                Button("\(minute) min") { add(minutes: minute) }
            }
        }
    }

    private func add(minutes: Int) {
        let seconds = TimeInterval(minutes * 60)
        guard !store.snoozeIntervals.contains(seconds) else { return }
        store.snoozeIntervals = (store.snoozeIntervals + [seconds]).sorted()
    }

    private func remove(minutes: Int) {
        store.snoozeIntervals.removeAll { $0 == TimeInterval(minutes * 60) }
    }
}
