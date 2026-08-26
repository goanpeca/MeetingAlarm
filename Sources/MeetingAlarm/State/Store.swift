import Combine
import Foundation

/// Persists armed meetings, snooze targets, and all settings under a single JSON blob
/// in `UserDefaults`. `@MainActor` so it can drive SwiftUI directly.
@MainActor
final class Store: ObservableObject {
    @Published var armed: [String: ArmedConfig] = [:]
    @Published var snoozes: [String: Date] = [:]
    @Published var activeSource: SourceKind = .eventKit {
        didSet { save() }
    }

    @Published var defaultPresetName: String = "Blast" {
        didSet { save() }
    }

    @Published var syncInterval: TimeInterval = 300 {
        didSet { save() }
    }

    @Published var snoozeIntervals: [TimeInterval] = [60, 300, 600] {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let key = "state.v1"
    private var loading = false

    private struct Snapshot: Codable {
        var armed: [String: ArmedConfig]
        var snoozes: [String: Date]
        var activeSource: SourceKind
        var defaultPresetName: String
        var syncInterval: TimeInterval
        var snoozeIntervals: [TimeInterval]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func arm(_ meeting: Meeting, preset: String) {
        armed[meeting.id] = ArmedConfig(presetName: preset, meeting: meeting)
        save()
    }

    func disarm(_ id: String) {
        armed[id] = nil
        save()
    }

    func setSnooze(_ id: String, at date: Date) {
        snoozes[id] = date
        save()
    }

    func clearSnooze(_ id: String) {
        snoozes[id] = nil
        save()
    }

    func prunePastSnoozes(now: Date) {
        snoozes = snoozes.filter { $0.value > now }
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }
        loading = true
        armed = snap.armed
        snoozes = snap.snoozes
        activeSource = snap.activeSource
        defaultPresetName = snap.defaultPresetName
        syncInterval = snap.syncInterval
        snoozeIntervals = snap.snoozeIntervals
        loading = false
    }

    private func save() {
        guard !loading else { return }
        let snap = Snapshot(
            armed: armed,
            snoozes: snoozes,
            activeSource: activeSource,
            defaultPresetName: defaultPresetName,
            syncInterval: syncInterval,
            snoozeIntervals: snoozeIntervals
        )
        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: key)
        }
    }
}
