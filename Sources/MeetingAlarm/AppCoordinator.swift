import Combine
import Foundation

/// Wires state + calendar source + scheduler together and drives the day-scoped list.
@MainActor
final class AppCoordinator: ObservableObject {
    @Published private(set) var meetings: [Meeting] = []
    @Published var selectedDay: Date = .init()
    @Published private(set) var errorMessage: String?
    @Published private(set) var needsPermission = false

    let store: Store
    let accounts: GoogleAccountStore

    let auth: GoogleAuth

    private let secrets: SecretStore
    private let overlay = OverlayController()
    private let sound = SoundPlayer()
    private let scheduler: AlarmScheduler
    private var source: CalendarSource
    private var syncTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let calendar = Calendar.current
    private let log = Log.make("coordinator")

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
        start()
    }

    private func rebuildSource() {
        switch store.activeSource {
        case .eventKit: source = EventKitSource()
        case .google: source = GoogleCalendarSource(auth: auth, accounts: accounts)
        }
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
            self?.store.clearSnooze(id)
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
                let interval = self?.store.syncInterval ?? 300
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

    // MARK: Day navigation

    func today() {
        setDay(Date())
    }

    func nextDay() {
        setDay(DayWindow.shift(selectedDay, byDays: 1, calendar: calendar))
    }

    func prevDay() {
        setDay(DayWindow.shift(selectedDay, byDays: -1, calendar: calendar))
    }

    private func setDay(_ day: Date) {
        selectedDay = day
        Task { await sync() }
    }

    // MARK: Arming

    func isArmed(_ meeting: Meeting) -> Bool {
        store.armed[meeting.id] != nil
    }

    func toggleArm(_ meeting: Meeting) {
        if isArmed(meeting) {
            store.disarm(meeting.id)
        } else {
            store.arm(meeting, preset: store.defaultPresetName)
        }
        reschedule()
    }

    func setPreset(_ meeting: Meeting, preset: String) {
        guard isArmed(meeting) else { return }
        store.arm(meeting, preset: preset)
        reschedule()
    }

    var hasMultipleAccounts: Bool {
        accounts.accounts.count > 1
    }

    // MARK: Google accounts

    var googleClientId: String {
        auth.clientId
    }

    var isGoogleConfigured: Bool {
        auth.isConfigured
    }

    func setGoogleCredentials(clientId: String, clientSecret: String) {
        auth.setCredentials(clientId: clientId, clientSecret: clientSecret)
    }

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

    func removeGoogleAccount(id: String) {
        auth.removeAccount(id: id)
        Task { await sync() }
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
        sound.play(profile.sound, volume: profile.volume, repeats: profile.soundRepeats)
    }

    /// A preset with the user's global color/effect/sound choices applied.
    private func effectiveProfile(named name: String) -> SensoryProfile {
        var profile = SensoryProfile.presets.first { $0.name == name } ?? .blast
        profile.color = store.alarmColor
        profile.effect = store.alarmEffect
        profile.leadTime = TimeInterval(store.leadTimeMinutes * 60)
        if !store.soundEnabled {
            profile.sound = nil
        }
        return profile
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

    private func reschedule() {
        scheduler.snoozeIntervals = store.snoozeIntervals
        scheduler.dismissChallenge = store.dismissChallenge
        scheduler.reschedule(armed: store.armed, snoozes: store.snoozes, now: Date())
    }
}
