import AppKit
import SwiftUI

/// Presents the alarm overlay as a borderless window on every screen, and guarantees
/// the safety invariant: **Esc always dismisses**.
@MainActor
final class OverlayController {
    private var windows: [NSWindow] = []
    private var keyMonitor: Any?

    func present(
        profile: SensoryProfile,
        meeting: Meeting,
        snoozeIntervals: [TimeInterval],
        onSnooze: @escaping (TimeInterval) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        dismiss()

        let dismissAll = { [weak self] in
            self?.dismiss()
            onDismiss()
        }
        let snooze = { [weak self] (interval: TimeInterval) in
            self?.dismiss()
            onSnooze(interval)
        }

        for screen in NSScreen.screens {
            let view = OverlayView(
                profile: profile,
                meeting: meeting,
                snoozeIntervals: snoozeIntervals,
                onSnooze: snooze,
                onDismiss: dismissAll
            )
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.contentView = NSHostingView(rootView: view)
            window.setFrame(screen.frame, display: true)
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc
                dismissAll()
                return nil
            }
            return event
        }
    }

    func dismiss() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}
