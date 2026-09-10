import SwiftUI

/// Per-meeting alarm customization, shown in a popover from the row's gear button. Each
/// control overrides a global setting; turning it off inherits the global value again. For a
/// recurring event a scope picker asks whether the change applies to this event or the whole
/// series (like macOS Calendar). Color is chosen from an inline palette rather than the system
/// color panel, which would steal focus and dismiss this menu-bar popover.
struct MeetingOverridesView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var store: Store
    let meeting: Meeting

    /// Which scope edits are written to. Only meaningful (and shown) for recurring events.
    @State private var scope: AppCoordinator.OverrideScope = .occurrence

    /// The OS accent (so a meeting can match the system) followed by the fixed palette.
    private let swatches: [RGBAColor] = [SystemAccent.rgba()] + RGBAColor.palette

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
            if overrides.color != nil {
                palette
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

    // MARK: Color palette

    /// Tappable swatches. Choosing one applies immediately at the selected scope — no system
    /// color panel, so the popover (and its scope choice) stays put.
    private var palette: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 30), spacing: 8)],
            alignment: .leading, spacing: 8
        ) {
            ForEach(swatches.indices, id: \.self) { index in
                swatchButton(swatches[index])
            }
        }
    }

    private func swatchButton(_ rgb: RGBAColor) -> some View {
        let selected = overrides.color == rgb
        return Button {
            coordinator.setColorOverride(meeting, color: rgb, scope: scope)
        } label: {
            Circle()
                .fill(color(rgb))
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(
                    selected ? Color.primary : Color.secondary.opacity(0.35),
                    lineWidth: selected ? 3 : 1
                ))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Alarm color")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
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

    private func color(_ rgb: RGBAColor) -> Color {
        Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }
}
