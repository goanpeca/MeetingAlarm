import AppKit
import Foundation

/// Arms a timer per armed meeting (or its active snooze) and fires the overlay + sound
/// at the right moment. Timer bookkeeping only — the *when* is `AlarmMath` (pure, tested).
@MainActor
final class AlarmScheduler {
    /// Snooze options offered on the overlay.
    var snoozeIntervals: [TimeInterval] = [60, 300, 600]
    /// The puzzle gating the Dismiss button.
    var dismissChallenge: DismissChallenge = .math
    /// Whether the alarm sound repeats until dismissed, and the gap between repeats.
    var soundRepeat = true
    var soundGap: TimeInterval = 1
    /// Resolve a preset name to a profile.
    var resolveProfile: (ArmedConfig) -> SensoryProfile = { _ in .blast }
    /// Called when the user snoozes a fired alarm.
    var onSnooze: (String, TimeInterval) -> Void = { _, _ in }
    /// Called when the user dismisses a fired alarm.
    var onDismiss: (String) -> Void = { _ in }
    /// Called after the machine wakes, so the owner can re-sync + reschedule.
    var onWake: () -> Void = {}

    private let overlay: OverlayController
    private let sound: SoundPlayer
    private var tasks: [String: Task<Void, Never>] = [:]
    private let log = Log.make("scheduler")

    init(overlay: OverlayController, sound: SoundPlayer) {
        self.overlay = overlay
        self.sound = sound
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onWake() }
        }
    }

    /// One armed alarm with its resolved profile and fire target.
    private struct Pending {
        let id: String
        let config: ArmedConfig
        let profile: SensoryProfile
        let target: Date
    }

    /// Cancel all timers and re-arm from the current armed set + snoozes. Due alarms present
    /// earliest-first, one at a time; the rest wait for the reschedule after it closes.
    func reschedule(armed: [String: ArmedConfig], snoozes: [String: Date], now: Date) {
        cancelAll()
        let pending = armed.compactMap { id, config -> Pending? in
            guard config.meeting.end > now else { return nil } // meeting already over
            let profile = resolveProfile(config)
            let target = snoozes[id]
                ?? AlarmMath.fireTime(
                    meetingStart: config.meeting.start,
                    leadTime: profile.leadTime
                )
            return Pending(id: id, config: config, profile: profile, target: target)
        }
        for alarm in pending.sorted(by: { $0.target < $1.target }) {
            let action = AlarmMath.fireAction(
                target: alarm.target, now: now, isPresenting: overlay.isPresenting
            )
            switch action {
            case .fireNow:
                fire(id: alarm.id, config: alarm.config, profile: alarm.profile)
            case let .schedule(after: delay):
                tasks[alarm.id] = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                    self?.fire(id: alarm.id, config: alarm.config, profile: alarm.profile)
                }
            case .wait:
                logWaiting(alarm.id)
            }
        }
    }

    private func fire(id: String, config: ArmedConfig, profile: SensoryProfile) {
        // One overlay at a time: never re-present or replace the alarm on screen.
        guard !overlay.isPresenting else {
            logWaiting(id)
            return
        }
        log.info("firing alarm for \(id, privacy: .public)")
        sound.play(
            profile.sound, volume: profile.volume, repeatForever: soundRepeat, gap: soundGap
        )
        overlay.present(
            profile: profile,
            meeting: config.meeting,
            snoozeIntervals: snoozeIntervals,
            challenge: dismissChallenge,
            onSnooze: { [weak self] interval in
                self?.sound.stop()
                self?.onSnooze(id, interval)
            },
            onDismiss: { [weak self] in
                self?.sound.stop()
                self?.onDismiss(id)
            }
        )
    }

    private func logWaiting(_ id: String) {
        log.info("alarm \(id, privacy: .public) waiting: another alarm is on screen")
    }

    private func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
}
