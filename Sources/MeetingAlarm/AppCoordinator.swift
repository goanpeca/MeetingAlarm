import Combine
import Foundation

/// Wires state + calendar source + scheduler together and drives the day-scoped list.
@MainActor
final class AppCoordinator: ObservableObject {
    @Published private(set) var meetings: [Meeting] = []
    @Published private(set) var availableCalendars: [CalendarInfo] = []
    @Published var selectedDay: Date = .init()
    @Published private(set) var errorMessage: String?
    @Published private(set) var needsPermission = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var isPreviewingSound = false
    /// A pending recurring-scope question, shown as an in-popover overlay.
    @Published var scopePrompt: ScopePrompt?

    let store: Store
    let accounts: GoogleAccountStore

    let auth: GoogleAuth

    private let secrets: SecretStore
    private let overlay = OverlayController()
    private let sound = SoundPlayer()
    private let scheduler: AlarmScheduler
    var source: CalendarSource
    private var syncTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    let calendar = Calendar.current
    private let log = Log.make("coordinator")
    private var quickPanel: QuickPanelController?
    /// How far ahead a whole armed series is pre-scheduled, plus a throttle so the extra
    /// horizon fetch doesn't run on every poll. Internal so `AppCoordinator+Scheduling` uses them.
    let seriesHorizon: TimeInterval = 60 * 24 * 60 * 60
    var lastSeriesMaterialize = Date.distantPast

    init(store: Store = Store(), accounts: GoogleAccountStore = GoogleAccountStore()) {
        self.store = store
        self.accounts = accounts
        secrets = KeychainSecretStore()
        auth = GoogleAuth(secrets: secrets, accounts: accounts)
        scheduler = AlarmScheduler(overlay: overlay, sound: sound)
        source = EventKitSource()
        configureScheduler()
        rebuildSource()
        observeSourceChanges()
        store.prunePastSnoozes(now: Date())
        quickPanel = QuickPanelController(coordinator: self)
        start()
    }

    private func rebuildSource() {
        switch store.activeSource {
        case .eventKit: source = EventKitSource()
        case .google: source = GoogleCalendarSource(auth: auth, accounts: accounts)
        }
        source.hiddenCalendarIds = store.hiddenCalendarIds
        source.onChange = { [weak self] in
            Task { await self?.sync() }
        }
    }

    private func observeSourceChanges() {
        store.$activeSource
            .dropFirst()
            .sink { [weak self] _ in
                self?.rebuildSource()
                Task { await self?.sync() }
            }
            .store(in: &cancellables)
    }

    private func configureScheduler() {
        scheduler.snoozeIntervals = store.snoozeIntervals
        scheduler.resolveProfile = { [weak self] name in
            self?.effectiveProfile(named: name) ?? .blast
        }
        scheduler.onSnooze = { [weak self] id, interval in
            self?.handleSnooze(id: id, interval: interval)
        }
        scheduler.onDismiss = { [weak self] id in
            // Dismiss = handled: clear any snooze and mark it handled so rescheduling can't
            // re-fire the overdue alarm — while keeping it armed (checked) as history.
            self?.store.clearSnooze(id)
            self?.store.markHandled(id)
            self?.reschedule()
        }
        scheduler.onWake = { [weak self] in
            self?.reschedule()
            Task { await self?.sync() }
        }
    }

    private func start() {
        reschedule()
        syncTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sync()
                // Poll at least every 30s so edited events surface promptly.
                let interval = min(self?.store.syncInterval ?? 60, 30)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    /// Fetch the selected day's meetings from the active source.
    func sync() async {
        do {
            try await source.authorize()
            needsPermission = false
            let interval = DayWindow.interval(for: selectedDay, calendar: calendar)
            meetings = try await source.fetchUpcoming(within: interval)
            reconcileArmed()
            await materializeSeries()
            availableCalendars = await source.availableCalendars()
            errorMessage = nil
            let count = meetings.count
            let kind = source.kind.rawValue
            log
                .notice(
                    "sync ok: \(count, privacy: .public) events, source=\(kind, privacy: .public)"
                )
        } catch {
            if case CalendarError.accessDenied = error {
                needsPermission = true
            }
            errorMessage = error.localizedDescription
            log.error("sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Force the calendar backend to refetch from the server, then re-sync. Keeps the
    /// spinner up briefly so the refresh reads as deliberate.
    func refresh() async {
        isRefreshing = true
        await source.refresh()
        await sync()
        try? await Task.sleep(for: .milliseconds(400))
        isRefreshing = false
    }

    var hasMultipleAccounts: Bool {
        accounts.accounts.count > 1
    }

    // MARK: Google accounts

    func addGoogleAccount() async {
        do {
            _ = try await auth.addAccount()
            errorMessage = nil
            await sync()
        } catch {
            errorMessage = error.localizedDescription
            log.error("add account failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Test

    func testAlarm() {
        let sample = Meeting(
            id: "test", title: "Test Alarm",
            start: Date().addingTimeInterval(360),
            end: Date().addingTimeInterval(3960),
            sourceKind: .eventKit, accountLabel: nil,
            joinURLs: [
                URL(string: "https://meet.google.com/lookup/demo"),
                URL(string: "https://zoom.us/j/1234567890")
            ].compactMap(\.self)
        )
        let profile = effectiveProfile(named: store.defaultPresetName)
        overlay.present(
            profile: profile, meeting: sample, snoozeIntervals: store.snoozeIntervals,
            challenge: store.dismissChallenge,
            onSnooze: { [weak self] _ in self?.sound.stop() },
            onDismiss: { [weak self] in self?.sound.stop() }
        )
        sound.play(
            profile.sound, volume: profile.volume,
            repeatForever: store.soundRepeat, gap: store.soundGapSeconds
        )
    }

    /// A preset with the user's global color/effect/sound choices applied.
    private func effectiveProfile(named name: String) -> SensoryProfile {
        var profile = SensoryProfile.presets.first { $0.name == name } ?? .blast
        profile.color = store.alarmColor
        profile.effect = store.alarmEffect
        profile.leadTime = TimeInterval(store.leadTimeMinutes * 60)
        profile.sound = store.soundEnabled ? store.alarmSound : nil
        profile.volume = store.alarmVolume
        return profile
    }

    /// Play the currently selected sound once, for the Settings preview button.
    /// Toggle a preview that mirrors real playback (looping with the configured gap when
    /// "repeat" is on), so the button flips to Stop while a looping preview plays.
    func togglePreview() {
        if isPreviewingSound {
            sound.stop()
            isPreviewingSound = false
            return
        }
        sound.play(
            store.alarmSound, volume: store.alarmVolume,
            repeatForever: store.soundRepeat, gap: store.soundGapSeconds
        )
        isPreviewingSound = store.soundRepeat
    }

    // MARK: Snooze

    private func handleSnooze(id: String, interval: TimeInterval) {
        if let config = store.armed[id],
           let target = AlarmMath.snoozeFireTime(
               from: Date(), interval: interval, meetingStart: config.meeting.start
           ) {
            store.setSnooze(id, at: target)
        }
        reschedule()
    }

    func reschedule() {
        scheduler.snoozeIntervals = store.snoozeIntervals
        scheduler.dismissChallenge = store.dismissChallenge
        scheduler.soundRepeat = store.soundRepeat
        scheduler.soundGap = store.soundGapSeconds
        let active = store.armed.filter { !store.handled.contains($0.key) }
        scheduler.reschedule(armed: active, snoozes: store.snoozes, now: Date())
    }
}
