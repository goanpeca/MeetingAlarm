import AppKit
import SwiftUI

/// The full-screen overlay content: the chosen visual effect, a live countdown, an
/// optional Join button, and snooze/dismiss controls.
struct OverlayView: View {
    let profile: SensoryProfile
    let meeting: Meeting
    let snoozeIntervals: [TimeInterval]
    let onSnooze: (TimeInterval) -> Void
    let onDismiss: () -> Void

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
            HStack(spacing: 14) {
                if let url = meeting.joinURL {
                    Button("Join meeting") { NSWorkspace.shared.open(url) }
                }
                ForEach(snoozeIntervals, id: \.self) { interval in
                    Button("Snooze \(Int(interval / 60))m") { onSnooze(interval) }
                }
                Button("Dismiss", role: .cancel) { onDismiss() }
            }
            .font(.title3)
            .buttonStyle(.borderedProminent)
            Text("Press Esc to dismiss").font(.callout).opacity(0.7)
        }
        .foregroundStyle(.white)
        .padding(40)
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
