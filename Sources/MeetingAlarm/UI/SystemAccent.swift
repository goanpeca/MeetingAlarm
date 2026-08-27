import AppKit

/// The user's macOS accent color (System Settings › Appearance › Theme Color), converted to
/// a framework-free `RGBAColor`. Used as the default alarm color so a fresh install matches
/// the OS out of the box. When "Multicolor" is selected, `controlAccentColor` is the
/// standard blue.
enum SystemAccent {
    static func rgba() -> RGBAColor {
        let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? NSColor.systemBlue
        return RGBAColor(
            red: Double(accent.redComponent),
            green: Double(accent.greenComponent),
            blue: Double(accent.blueComponent),
            alpha: 1
        )
    }
}
