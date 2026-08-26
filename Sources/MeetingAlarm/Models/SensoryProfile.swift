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

/// How the overlay reaches its peak intensity.
enum Escalation: String, Codable, Sendable {
    /// Jump straight to peak (used by `Blast`).
    case instant
    /// Ramp up over `leadTime` (used by `Gentle Ramp`).
    case easeIn
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
/// ``gentleRamp``. See the design doc §9 for the accessibility rationale behind
/// the Gentle Ramp preset.
struct SensoryProfile: Codable, Sendable, Equatable {
    /// Human-facing preset name.
    var name: String
    /// Overlay color.
    var color: RGBAColor
    /// Final overlay opacity, 0...1.
    var peakOpacity: Double
    /// Seconds BEFORE the meeting start that the overlay begins.
    var leadTime: TimeInterval
    /// How intensity is reached.
    var escalation: Escalation
    /// Gentle oscillation; ignored when the system Reduce Motion setting is on.
    var pulse: Bool
    /// Sound to play, or `nil` for silent.
    var sound: SoundChoice?
    /// Playback volume, 0...1.
    var volume: Double
    /// Configured dismissal (Esc always works too).
    var dismissal: Dismissal
    /// Whether to render a live countdown to the meeting start.
    var showCountdown: Bool

    /// High-intensity, can't-miss interrupt fired AT meeting time.
    static let blast = SensoryProfile(
        name: "Blast",
        color: .red,
        peakOpacity: 0.85,
        leadTime: 0,
        escalation: .instant,
        pulse: true,
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
        escalation: .easeIn,
        pulse: false,
        sound: .chime,
        volume: 0.4,
        dismissal: .keyPress,
        showCountdown: true
    )

    /// The presets offered in the UI, in display order.
    static let presets: [SensoryProfile] = [.blast, .gentleRamp]
}

extension SensoryProfile {
    /// The overlay opacity at a point along the ramp.
    ///
    /// - Parameters:
    ///   - fraction: Progress from the overlay's start to the meeting start,
    ///     `0` (just appeared) ... `1` (meeting starting). Values outside the
    ///     range are clamped.
    ///   - reduceMotion: When `true`, easing is replaced by a linear rise so
    ///     there is no acceleration — honoring the system Reduce Motion setting.
    /// - Returns: An opacity in `0 ... peakOpacity`.
    ///
    /// `.instant` profiles (Blast) are at `peakOpacity` the moment they fire;
    /// `.easeIn` profiles (Gentle Ramp) rise smoothly (quadratic) from `0`.
    func overlayOpacity(atFraction fraction: Double, reduceMotion: Bool = false) -> Double {
        let clamped = min(max(fraction, 0), 1)
        switch escalation {
        case .instant:
            return peakOpacity
        case .easeIn:
            let curve = reduceMotion ? clamped : clamped * clamped
            return peakOpacity * curve
        }
    }
}
