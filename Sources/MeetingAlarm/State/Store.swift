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
    /// Series ids the user armed wholesale → preset name. Individual occurrences are
    /// materialized from these each sync (see `AppCoordinator.materializeSeries`).
    @Published var armedSeries: [String: String] = [:]
    /// Per-series occurrence ids the user chose to skip ("this event only").
    @Published var seriesExceptions: [String: Set<String>] = [:]
    @Published var activeSource: SourceKind = .eventKit {
        didSet { save() }
    }

    @Published var defaultPresetName: String = "Gentle Ramp" {
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
        var activeSource: SourceKind
        var defaultPresetName: String
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

    func arm(_ meeting: Meeting, preset: String) {
        armed[meeting.id] = ArmedConfig(presetName: preset, meeting: meeting)
        handled.remove(meeting.id)
        save()
    }

    func disarm(_ id: String) {
        armed[id] = nil
        handled.remove(id)
        save()
    }

    /// Mark a fired+dismissed occurrence handled (stays armed for history, won't re-fire).
    func markHandled(_ id: String) {
        handled.insert(id)
        save()
    }

    /// Refresh an armed occurrence's snapshot (e.g. its time was edited) so the alarm
    /// re-times; a moved event also un-handles so it can fire again.
    func updateArmed(_ meeting: Meeting) {
        guard let config = armed[meeting.id] else { return }
        armed[meeting.id] = ArmedConfig(presetName: config.presetName, meeting: meeting)
        handled.remove(meeting.id)
        save()
    }

    // MARK: Series arming

    /// Arm a whole recurring series with `preset`. Clears any prior per-occurrence skips.
    func armSeries(_ seriesId: String, preset: String) {
        armedSeries[seriesId] = preset
        seriesExceptions[seriesId] = nil
        save()
    }

    /// Disarm a whole series and drop its materialized occurrences and skips.
    func disarmSeries(_ seriesId: String) {
        armedSeries[seriesId] = nil
        seriesExceptions[seriesId] = nil
        armed = armed.filter { !($0.value.fromSeries && $0.value.meeting.seriesId == seriesId) }
        save()
    }

    /// Skip a single occurrence of an armed series ("this event only").
    func addSeriesException(seriesId: String, occurrenceId: String) {
        seriesExceptions[seriesId, default: []].insert(occurrenceId)
        armed[occurrenceId] = nil
        save()
    }

    /// Replace all series-materialized entries with a freshly computed set, leaving
    /// explicitly-armed occurrences untouched. Returns true only when something changed
    /// (so callers can skip a needless reschedule).
    func setMaterializedSeries(_ entries: [SeriesMaterializer.Entry]) -> Bool {
        var next = armed.filter { !$0.value.fromSeries }
        for entry in entries {
            next[entry.meeting.id] = ArmedConfig(
                presetName: entry.preset, meeting: entry.meeting, fromSeries: true
            )
        }
        guard next != armed else { return false }
        armed = next
        save()
        return true
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
        activeSource = snap.activeSource
        defaultPresetName = snap.defaultPresetName
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

    private func save() {
        guard !loading else { return }
        let snap = Snapshot(
            armed: armed,
            snoozes: snoozes,
            handled: Array(handled),
            armedSeries: armedSeries,
            seriesExceptions: seriesExceptions.mapValues(Array.init),
            activeSource: activeSource,
            defaultPresetName: defaultPresetName,
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
