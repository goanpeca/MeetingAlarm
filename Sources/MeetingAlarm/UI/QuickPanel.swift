import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A floating panel that mirrors the menu-bar popover, summoned by a global hot key
/// (⌃⌥⌘M) so the app stays reachable even when its menu-bar icon is hidden — e.g. pushed
/// off-screen behind the notch. Toggling the hot key shows/hides it; Escape or clicking away
/// closes it.
@MainActor
final class QuickPanelController {
    private let coordinator: AppCoordinator
    private var panel: NSPanel?
    private var hotKey: GlobalHotKey?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        NotificationCenter.default.addObserver(
            forName: .meetingAlarmSummon, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.toggle() }
        }
        hotKey = GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_M),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )
    }

    private func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
        } else {
            present()
        }
    }

    private func present() {
        let panel = panel ?? makePanel()
        self.panel = panel
        if let screen = NSScreen.main {
            let frame = panel.frame
            panel.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - frame.width / 2,
                y: screen.visibleFrame.maxY - frame.height - 12
            ))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func makePanel() -> NSPanel {
        let hosting = NSHostingView(rootView: RootView(coordinator: coordinator))
        hosting.sizingOptions = [.preferredContentSize]
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 460),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.contentView = hosting
        let fitting = hosting.fittingSize
        panel.setContentSize(fitting.width > 0 ? fitting : NSSize(width: 360, height: 460))
        return panel
    }
}
