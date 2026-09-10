import Combine
import Foundation

/// Persists armed meetings, snooze targets, and all settings under a single JSON blob
/// in `UserDefaults`. `@MainActor` so it can drive SwiftUI directly.
@MainActor
final class Store: ObservableObject {
    @Published var armed: [String: ArmedConfig] = [:]
    @Published var snoozes: [String: Date] = [:]
    /// Ids that already fired + were dismissed: kept armed (checked, as history) but not
    /// re-scheduled, so an overdue alarm can't re-fire.
    @Published var handled: Set<String> = []
    /// Series ids the user armed wholesale → preset name. The scheduler treats every occurrence
    /// of these series as armed as they roll into its window.
    @Published var armedSeries: [String: String] = [:]
    /// Per-series occurrence ids the user chose to skip ("this event only").
    @Published var seriesExceptions: [String: Set<String>] = [:]
    /// Future occurrences the user explicitly opted out of. In auto-arm (opt-out) mode every
    /// other meeting is armed automatically, so this is an exclusion list rather than an armed
    /// list; with auto-arm off it simply suppresses the derived default for those occurrences.
    @Published var excludedMeetingIds: Set<String> = []
    /// Recurring series the user opted out of wholesale. A later explicit arm of one
    /// occurrence still takes precedence, letting it be re-enabled on its own.
    @Published var excludedSeriesIds: Set<String> = []
    /// Per-meeting alarm overrides (color/sound), keyed by occurrence id.
    @Published var armOverrides: [String: AlarmOverrides] = [:]
    /// Per-series alarm overrides (color/sound), keyed by series id. An occurrence's own
    /// override wins; otherwise it inherits its series' override, then the global settings.
    @Published var seriesOverrides: [String: AlarmOverrides] = [:]
    @Published var activeSource: SourceKind = .eventKit {
        didSet { save() }
    }

    @Published var defaultPresetName: String = "Gentle Ramp" {
        didSet { save() }
    }

    /// Arm every future meeting automatically (opt-out), rather than only the ones the user
    /// checks (opt-in). Off by default — the app stays a deliberate per-meeting choice unless
    /// the user turns this on in Settings.
    @Published var autoArm: Bool = false {
        didSet { save() }
    }

    @Published var syncInterval: TimeInterval = 300 {
        didSet { save() }
    }

    @Published var snoozeIntervals: [TimeInterval] = [60, 300, 600] {
        didSet { save() }
    }

    @Published var soundEnabled: Bool = true {
        didSet { save() }
    }

    @Published var alarmSound: SoundChoice = .jewelDrop {
        didSet { save() }
    }

    @Published var soundRepeat: Bool = true {
        didSet { save() }
    }

    @Published var soundGapSeconds: Double = 1 {
        didSet { save() }
    }

    @Published var alarmVolume: Double = 1 {
        didSet { save() }
    }

    @Published var alarmColor: RGBAColor {
        didSet { save() }
    }

    @Published var alarmEffect: Effect = .solid {
        didSet { save() }
    }

    @Published var leadTimeMinutes: Int = 5 {
        didSet { save() }
    }

    @Published var dismissChallenge: DismissChallenge = .math {
        didSet { save() }
    }

    /// Calendar ids the user has hidden from the day list. Empty = show all.
    @Published var hiddenCalendarIds: Set<String> = [] {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let key = "state.v1"
    private let defaultAlarmColor: RGBAColor
    private var loading = false

    private struct Snapshot: Codable {
        var armed: [String: ArmedConfig]
        var snoozes: [String: Date]
        var handled: [String]?
        var armedSeries: [String: String]?
        var seriesExceptions: [String: [String]]?
        var excludedMeetingIds: [String]?
        var excludedSeriesIds: [String]?
        var armOverrides: [String: AlarmOverrides]?
        var seriesOverrides: [String: AlarmOverrides]?
        var activeSource: SourceKind
        var defaultPresetName: String
        var autoArm: Bool?
        var syncInterval: TimeInterval
        var snoozeIntervals: [TimeInterval]
        // Optional so state saved before these settings existed still decodes.
        var soundEnabled: Bool?
        var alarmSound: SoundChoice?
        var soundRepeat: Bool?
        var soundGapSeconds: Double?
        var alarmVolume: Double?
        var alarmColor: RGBAColor?
        var alarmEffect: Effect?
        var leadTimeMinutes: Int?
        var dismissChallenge: DismissChallenge?
        var hiddenCalendarIds: [String]?
    }

    init(defaults: UserDefaults = .standard, defaultAlarmColor: RGBAColor = .red) {
        self.defaults = defaults
        self.defaultAlarmColor = defaultAlarmColor
        alarmColor = defaultAlarmColor
        load()
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
        handled = Set(snap.handled ?? [])
        armedSeries = snap.armedSeries ?? [:]
        seriesExceptions = (snap.seriesExceptions ?? [:]).mapValues(Set.init)
        excludedMeetingIds = Set(snap.excludedMeetingIds ?? [])
        excludedSeriesIds = Set(snap.excludedSeriesIds ?? [])
        armOverrides = snap.armOverrides ?? [:]
        seriesOverrides = snap.seriesOverrides ?? [:]
        activeSource = snap.activeSource
        defaultPresetName = snap.defaultPresetName
        autoArm = snap.autoArm ?? false
        syncInterval = snap.syncInterval
        snoozeIntervals = snap.snoozeIntervals
        soundEnabled = snap.soundEnabled ?? true
        alarmSound = snap.alarmSound ?? .jewelDrop
        soundRepeat = snap.soundRepeat ?? true
        soundGapSeconds = snap.soundGapSeconds ?? 1
        alarmVolume = snap.alarmVolume ?? 1
        alarmColor = snap.alarmColor ?? defaultAlarmColor
        alarmEffect = snap.alarmEffect ?? .solid
        leadTimeMinutes = snap.leadTimeMinutes ?? 5
        dismissChallenge = snap.dismissChallenge ?? .math
        hiddenCalendarIds = Set(snap.hiddenCalendarIds ?? [])
        loading = false
    }

    func save() {
        guard !loading else { return }
        let snap = Snapshot(
            armed: armed,
            snoozes: snoozes,
            handled: Array(handled),
            armedSeries: armedSeries,
            seriesExceptions: seriesExceptions.mapValues(Array.init),
            excludedMeetingIds: Array(excludedMeetingIds),
            excludedSeriesIds: Array(excludedSeriesIds),
            armOverrides: armOverrides,
            seriesOverrides: seriesOverrides,
            activeSource: activeSource,
            defaultPresetName: defaultPresetName,
            autoArm: autoArm,
            syncInterval: syncInterval,
            snoozeIntervals: snoozeIntervals,
            soundEnabled: soundEnabled,
            alarmSound: alarmSound,
            soundRepeat: soundRepeat,
            soundGapSeconds: soundGapSeconds,
            alarmVolume: alarmVolume,
            alarmColor: alarmColor,
            alarmEffect: alarmEffect,
            leadTimeMinutes: leadTimeMinutes,
            dismissChallenge: dismissChallenge,
            hiddenCalendarIds: Array(hiddenCalendarIds)
        )
        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: key)
        }
    }
}
