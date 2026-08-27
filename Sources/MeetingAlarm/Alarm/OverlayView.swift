import AppKit
import SwiftUI

/// The full-screen overlay content: the chosen visual effect, a live countdown, an
/// optional Join button, and snooze/dismiss controls.
struct OverlayView: View {
    let profile: SensoryProfile
    let meeting: Meeting
    let snoozeIntervals: [TimeInterval]
    let challenge: DismissChallenge
    let onSnooze: (TimeInterval) -> Void
    let onDismiss: () -> Void

    /// Action queued behind the puzzle gate (Join or Dismiss); non-nil shows the gate.
    @State private var pending: (() -> Void)?

    private var color: Color {
        Color(
            .sRGB,
            red: profile.color.red,
            green: profile.color.green,
            blue: profile.color.blue,
            opacity: 1
        )
    }

    var body: some View {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            ZStack {
                background(now: context.date, reduceMotion: reduceMotion)
                content(now: context.date)
            }
        }
    }

    @ViewBuilder
    private func background(now: Date, reduceMotion: Bool) -> some View {
        let base = profile.overlayOpacity(
            atFraction: fraction(now: now),
            reduceMotion: reduceMotion
        )
        switch profile.effect {
        case .edgeGlow:
            RadialGradient(
                colors: [.clear, color.opacity(base)],
                center: .center,
                startRadius: 160,
                endRadius: 1000
            )
            .ignoresSafeArea()
        default:
            color
                .opacity(dynamicOpacity(base: base, now: now, reduceMotion: reduceMotion))
                .ignoresSafeArea()
        }
    }

    private func content(now: Date) -> some View {
        VStack(spacing: 18) {
            Text(meeting.title)
                .font(.system(size: 46, weight: .bold))
                .multilineTextAlignment(.center)
            if profile.showCountdown {
                Text(countdown(now: now)).font(.system(size: 30, weight: .medium))
            }
            if let label = meeting.accountLabel {
                Text(label).font(.title3).opacity(0.85)
            }
            if let notes = meeting.notes, !notes.isEmpty {
                ScrollView {
                    NotesView(html: notes)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 720)
                }
                .frame(maxHeight: 150)
                .opacity(0.9)
            }
            if !meeting.attendees.isEmpty {
                Label(attendeeSummary, systemImage: "person.2.fill")
                    .font(.title3)
                    .opacity(0.9)
            }
            if pending != nil {
                ChallengeGateView(
                    challenge: challenge,
                    onSolved: {
                        let action = pending
                        pending = nil
                        action?()
                    },
                    onCancel: { pending = nil }
                )
            } else {
                actionRows(now: now)
            }
        }
        .foregroundStyle(.white)
        .padding(40)
    }

    private func actionRows(now: Date) -> some View {
        VStack(spacing: 14) {
            if !meeting.joinURLs.isEmpty {
                HStack(spacing: 14) {
                    ForEach(meeting.joinURLs, id: \.self) { url in
                        Button(MeetingProvider.label(for: url)) { request { join(url) } }
                            .tint(MeetingProvider.color(for: url))
                    }
                }
            }
            let snoozes = availableSnoozes(now: now)
            if !snoozes.isEmpty {
                HStack(spacing: 14) {
                    ForEach(snoozes, id: \.self) { interval in
                        Button("Snooze \(Int(interval / 60))m") { onSnooze(interval) }
                            .tint(.gray)
                    }
                }
            }
            Button("Dismiss", role: .cancel) { request(onDismiss) }
                .tint(.red)
        }
        .font(.title3)
        .buttonStyle(.borderedProminent)
    }

    /// Run `action` now if there's no puzzle, else queue it behind the gate.
    private func request(_ action: @escaping () -> Void) {
        if challenge == .none {
            action()
        } else {
            pending = action
        }
    }

    private var attendeeSummary: String {
        let names = meeting.attendees
        guard names.count > 4 else { return names.joined(separator: ", ") }
        return names.prefix(3).joined(separator: ", ") + " +\(names.count - 3)"
    }

    /// Joining = the alarm did its job. Tear down the modal overlay first (which restores
    /// app switching and normal focus), THEN open the link so the browser/app comes to the
    /// front cleanly instead of fighting the kiosk-mode overlay.
    private func join(_ url: URL) {
        onDismiss()
        NSWorkspace.shared.open(url)
    }

    /// Only snooze options whose target still lands before the meeting starts.
    private func availableSnoozes(now: Date) -> [TimeInterval] {
        snoozeIntervals.filter { now.addingTimeInterval($0) < meeting.start }
    }

    private func fraction(now: Date) -> Double {
        guard profile.leadTime > 0 else { return 1 }
        let elapsed = profile.leadTime - meeting.start.timeIntervalSince(now)
        return max(0, min(1, elapsed / profile.leadTime))
    }

    private func countdown(now: Date) -> String {
        let remaining = Int(meeting.start.timeIntervalSince(now).rounded())
        if remaining <= 0 {
            return "Starting now"
        }
        return "in \(remaining / 60)m \(remaining % 60)s"
    }

    private func dynamicOpacity(base: Double, now: Date, reduceMotion: Bool) -> Double {
        let phase = now.timeIntervalSinceReferenceDate
        switch profile.effect {
        case .pulse:
            guard !reduceMotion else { return base }
            let osc = 0.5 + 0.5 * sin(phase * 2 * .pi / 1.6)
            return profile.peakOpacity * (0.35 + 0.65 * osc)
        case .flash:
            guard !reduceMotion else { return base }
            return phase.truncatingRemainder(dividingBy: 1.0) < 0.5 ? profile.peakOpacity : 0.06
        default:
            return base
        }
    }
}
