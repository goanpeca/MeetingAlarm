import AppKit
import SwiftUI

/// The full-screen overlay content: a color wash whose opacity follows the profile's
/// ramp, a live countdown, and snooze/dismiss controls.
struct OverlayView: View {
    let profile: SensoryProfile
    let meeting: Meeting
    let snoozeIntervals: [TimeInterval]
    let onSnooze: (TimeInterval) -> Void
    let onDismiss: () -> Void

    @State private var now = Date()
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var color: Color {
        Color(
            .sRGB,
            red: profile.color.red,
            green: profile.color.green,
            blue: profile.color.blue,
            opacity: 1
        )
    }

    private var fraction: Double {
        guard profile.leadTime > 0 else { return 1 }
        let elapsed = profile.leadTime - meeting.start.timeIntervalSince(now)
        return max(0, min(1, elapsed / profile.leadTime))
    }

    private var countdown: String {
        let remaining = Int(meeting.start.timeIntervalSince(now).rounded())
        if remaining <= 0 {
            return "Starting now"
        }
        let minutes = remaining / 60
        let seconds = remaining % 60
        return "in \(minutes)m \(seconds)s"
    }

    var body: some View {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        ZStack {
            color
                .opacity(profile.overlayOpacity(atFraction: fraction, reduceMotion: reduceMotion))
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Text(meeting.title)
                    .font(.system(size: 46, weight: .bold))
                    .multilineTextAlignment(.center)
                if profile.showCountdown {
                    Text(countdown).font(.system(size: 30, weight: .medium))
                }
                if let label = meeting.accountLabel {
                    Text(label).font(.title3).opacity(0.85)
                }
                HStack(spacing: 14) {
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
        .onReceive(tick) { now = $0 }
    }
}
