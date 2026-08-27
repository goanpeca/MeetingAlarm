import Foundation

/// Per-meeting overrides of the global alarm settings. A `nil` field inherits the global
/// value; a present field replaces it for that one meeting. Kept pure (no UI) so the
/// override logic is unit-testable. For now only color and sound are overridable.
struct AlarmOverrides: Codable, Sendable, Equatable {
    /// Replaces the global alarm color when set.
    var color: RGBAColor?
    /// Replaces the global alarm sound when set (including forcing silence).
    var sound: SoundOverride?

    /// No override present — the meeting fully inherits the global settings.
    var isEmpty: Bool {
        color == nil && sound == nil
    }
}

/// A per-meeting sound choice: force a specific sound, or force silence. Distinct from
/// "no override" (which is `AlarmOverrides.sound == nil`, i.e. inherit the global sound).
enum SoundOverride: Codable, Sendable, Equatable, Hashable {
    case silent
    case sound(SoundChoice)
}
