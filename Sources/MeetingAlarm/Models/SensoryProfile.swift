import Foundation

/// A display color as plain components (0...1), deliberately free of any UI
/// framework so the Models layer stays unit-testable without a screen. The UI
/// layer converts this to `Color` / `NSColor`.
struct RGBAColor: Codable, Sendable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    /// Alarm red for the high-intensity `Blast` preset.
    static let red = RGBAColor(red: 0.86, green: 0.15, blue: 0.15, alpha: 1)
    /// A calm teal for the sensory-safe `Gentle Ramp` preset.
    static let calmTeal = RGBAColor(red: 0.11, green: 0.44, blue: 0.52, alpha: 1)
}

/// The visual effect the overlay uses. Animated effects (`pulse`, `flash`) fall back to
/// a steady fill when the system Reduce Motion setting is on.
enum Effect: String, Codable, Sendable, CaseIterable {
    /// Steady fill at peak opacity.
    case solid
    /// Fades in gradually over the lead time (sensory-safe).
    case ramp
    /// Smooth breathing in and out.
    case pulse
    /// Hard on/off flashing — most attention-grabbing.
    case flash
    /// Only the screen edges glow; the center stays clear (least intrusive).
    case edgeGlow

    var displayName: String {
        switch self {
        case .solid: "Solid"
        case .ramp: "Gentle ramp"
        case .pulse: "Pulse"
        case .flash: "Flash"
        case .edgeGlow: "Edge glow"
        }
    }
}

/// Optional alarm sound. `nil` on a profile means silent.
enum SoundChoice: String, Codable, Sendable, CaseIterable {
    case chime
    case alarm
    case ping
}

/// How the user clears the overlay. Note: **Esc always dismisses** regardless of
/// this value — a hard safety invariant so the alert can never trap the user.
enum Dismissal: Codable, Sendable, Equatable {
    case clickAnywhere
    case keyPress
    case auto(after: TimeInterval)
}

/// The tunable behavior of one alarm. Two presets ship: ``blast`` and
/// ``gentleRamp``. Color, effect, and sound can be overridden globally in Settings.
struct SensoryProfile: Codable, Sendable, Equatable {
    /// Human-facing preset name.
    var name: String
    /// Overlay color.
    var color: RGBAColor
    /// Final overlay opacity, 0...1.
    var peakOpacity: Double
    /// Seconds BEFORE the meeting start that the overlay begins.
    var leadTime: TimeInterval
    /// The visual effect.
    var effect: Effect
    /// Sound to play, or `nil` for silent.
    var sound: SoundChoice?
    /// Playback volume, 0...1.
    var volume: Double
    /// Configured dismissal (Esc always works too).
    var dismissal: Dismissal
    /// Whether to render a live countdown to the meeting start.
    var showCountdown: Bool

    /// Whether the alarm sound should repeat until dismissed (for the intense effects).
    var soundRepeats: Bool {
        effect == .flash || effect == .solid
    }

    /// High-intensity, can't-miss interrupt fired AT meeting time.
    static let blast = SensoryProfile(
        name: "Blast",
        color: .red,
        peakOpacity: 0.85,
        leadTime: 0,
        effect: .flash,
        sound: .alarm,
        volume: 0.9,
        dismissal: .clickAnywhere,
        showCountdown: true
    )

    /// Predictable, sensory-safe alert that starts early and grows gently.
    static let gentleRamp = SensoryProfile(
        name: "Gentle Ramp",
        color: .calmTeal,
        peakOpacity: 0.4,
        leadTime: 300,
        effect: .ramp,
        sound: .chime,
        volume: 0.4,
        dismissal: .keyPress,
        showCountdown: true
    )

    /// The presets offered in the UI, in display order.
    static let presets: [SensoryProfile] = [.blast, .gentleRamp]
}

extension SensoryProfile {
    /// The base overlay opacity at a point along the lead time.
    ///
    /// - Parameters:
    ///   - fraction: Progress from the overlay's start to the meeting start,
    ///     `0` (just appeared) ... `1` (meeting starting). Clamped.
    ///   - reduceMotion: When `true`, `.ramp` easing becomes a linear rise so there
    ///     is no acceleration — honoring the system Reduce Motion setting.
    /// - Returns: An opacity in `0 ... peakOpacity`. Only `.ramp` grows in; every
    ///   other effect starts at `peakOpacity` (the view animates pulse/flash on top).
    func overlayOpacity(atFraction fraction: Double, reduceMotion: Bool = false) -> Double {
        guard effect == .ramp else { return peakOpacity }
        let clamped = min(max(fraction, 0), 1)
        let curve = reduceMotion ? clamped : clamped * clamped
        return peakOpacity * curve
    }
}
