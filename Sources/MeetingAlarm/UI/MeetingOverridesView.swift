import AppKit
import SwiftUI

/// Per-meeting alarm customization, shown in a popover from the row's gear button. Each
/// control overrides a global setting; turning it off inherits the global value again. For a
/// recurring event a scope picker asks whether the change applies to this event or the whole
/// series (like macOS Calendar). For now only color and sound are overridable.
struct MeetingOverridesView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var store: Store
    let meeting: Meeting

    @State private var colorPanel = ColorPanelController()
    /// Which scope edits are written to. Only meaningful (and shown) for recurring events.
    @State private var scope: AppCoordinator.OverrideScope = .occurrence

    private var overrides: AlarmOverrides {
        coordinator.overrides(for: meeting, scope: scope)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Customize this alarm").font(.headline)
            Text(coordinator.isRecurring(meeting)
                ? "Overrides the global color and sound for this recurring event."
                : "Overrides the global color and sound for this meeting only.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if coordinator.isRecurring(meeting) {
                Picker("Apply to", selection: $scope) {
                    Text("This event").tag(AppCoordinator.OverrideScope.occurrence)
                    Text("All in series").tag(AppCoordinator.OverrideScope.series)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Apply override to")
            }

            Toggle("Override color", isOn: colorEnabled)
            if let color = overrides.color {
                LabeledContent("Color") {
                    Button { openColorPanel(current: color) } label: { swatch(color) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Pick alarm color")
                }
            }

            Toggle("Override sound", isOn: soundEnabled)
            if overrides.sound != nil {
                Picker("Sound", selection: soundSelection) {
                    Text("Silent").tag(SoundOverride.silent)
                    ForEach(SoundChoice.allCases, id: \.self) { choice in
                        Text(choice.displayName).tag(SoundOverride.sound(choice))
                    }
                }
            }

            HStack {
                Spacer()
                Button("Reset to global") { coordinator.clearOverrides(meeting, scope: scope) }
                    .disabled(overrides.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 300)
        // Default to editing the series when it already carries an override.
        .onAppear { scope = coordinator.hasSeriesOverride(meeting) ? .series : .occurrence }
    }

    // MARK: Bindings

    private var colorEnabled: Binding<Bool> {
        Binding(
            get: { overrides.color != nil },
            set: { on in
                coordinator.setColorOverride(
                    meeting, color: on ? store.alarmColor : nil, scope: scope
                )
            }
        )
    }

    private var soundEnabled: Binding<Bool> {
        Binding(
            get: { overrides.sound != nil },
            set: { on in
                let initial: SoundOverride = store.soundEnabled ? .sound(store.alarmSound) : .silent
                coordinator.setSoundOverride(meeting, sound: on ? initial : nil, scope: scope)
            }
        )
    }

    private var soundSelection: Binding<SoundOverride> {
        Binding(
            get: { overrides.sound ?? .silent },
            set: { coordinator.setSoundOverride(meeting, sound: $0, scope: scope) }
        )
    }

    // MARK: Helpers

    private func swatch(_ color: RGBAColor) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: 1))
            .frame(width: 46, height: 22)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.secondary.opacity(0.4)))
    }

    private func openColorPanel(current: RGBAColor) {
        let ns = NSColor(
            srgbRed: current.red, green: current.green, blue: current.blue, alpha: 1
        )
        colorPanel.show(current: ns) { newColor in
            let converted = newColor.usingColorSpace(.sRGB) ?? newColor
            coordinator.setColorOverride(
                meeting,
                color: RGBAColor(
                    red: Double(converted.redComponent),
                    green: Double(converted.greenComponent),
                    blue: Double(converted.blueComponent),
                    alpha: 1
                ),
                scope: scope
            )
        }
    }
}
