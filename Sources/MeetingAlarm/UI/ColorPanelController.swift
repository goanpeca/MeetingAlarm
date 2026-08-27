import AppKit

/// Presents the shared `NSColorPanel` reliably from a menu-bar (accessory) app. SwiftUI's
/// `ColorPicker` opens the panel without activating the app, so it can appear *behind* the
/// frontmost window and read as "not visible". This activates the app and orders the panel
/// to the front, and streams color changes back to the caller.
@MainActor
final class ColorPanelController: NSObject {
    private var onChange: ((NSColor) -> Void)?

    func show(current: NSColor, onChange: @escaping (NSColor) -> Void) {
        self.onChange = onChange
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = current
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.isFloatingPanel = true
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        onChange?(sender.color)
    }
}
