import Foundation

/// Keyboard policy for the full-screen alarm overlay, kept pure so the "can never trap the
/// user" invariant is unit-tested instead of verified by hand.
enum OverlayKey {
    /// macOS virtual key code for Escape.
    static let escapeKeyCode: UInt16 = 53

    /// Whether a key press dismisses the overlay. Escape always does, whatever dismiss
    /// challenge is configured — the puzzle gates the Dismiss/Join buttons, never the escape
    /// hatch.
    static func dismisses(keyCode: UInt16, challenge _: DismissChallenge) -> Bool {
        keyCode == escapeKeyCode
    }
}
