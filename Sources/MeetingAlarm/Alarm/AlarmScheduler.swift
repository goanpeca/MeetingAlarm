import AppKit
import Foundation

/// Arms a timer per armed meeting (or its active snooze) and fires the overlay + sound
/// at the right moment. Timer bookkeeping only — the *when* is `AlarmMath` (pure, tested).
@MainActor
final class AlarmScheduler {
    /// Snooze options offered on the overlay.
    var snoozeIntervals: [TimeInterval] = [60, 300, 600]
    /// Optional puzzle gating the Dismiss button.
    var dismissChallenge: DismissChallenge = .none
    /// Resolve a preset name to a profile.
    var resolveProfile: (String) -> SensoryProfile = { _ in .blast }
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

    /// Cancel all timers and re-arm from the current armed set + snoozes.
    func reschedule(armed: [String: ArmedConfig], snoozes: [String: Date], now: Date) {
        cancelAll()
        for (id, config) in armed {
            guard config.meeting.end > now else { continue } // meeting already over
            let profile = resolveProfile(config.presetName)
            let target = snoozes[id]
                ?? AlarmMath.fireTime(
                    meetingStart: config.meeting.start,
                    leadTime: profile.leadTime
                )
            if target <= now {
                fire(id: id, config: config, profile: profile) // overdue → fire immediately
            } else {
                let delay = target.timeIntervalSince(now)
                tasks[id] = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                    self?.fire(id: id, config: config, profile: profile)
                }
            }
        }
    }

    private func fire(id: String, config: ArmedConfig, profile: SensoryProfile) {
        log.info("firing alarm for \(id, privacy: .public)")
        sound.play(profile.sound, volume: profile.volume, repeats: profile.soundRepeats)
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

    private func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
}
