import AppKit
import SwiftUI

/// A borderless window that can still become key, so the dismiss puzzle's text field can
/// receive typing.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}

/// Presents the alarm overlay on every screen as a modal, can't-escape surface: it covers
/// all displays, hides the Dock/menu bar, and disables app switching — the only ways out
/// are Snooze, a Join link, or Dismiss (which may require solving the configured puzzle).
/// Esc dismisses only when no dismiss challenge is set.
@MainActor
final class OverlayController {
    private var windows: [NSWindow] = []
    private var keyMonitor: Any?

    func present(
        profile: SensoryProfile,
        meeting: Meeting,
        snoozeIntervals: [TimeInterval],
        challenge: DismissChallenge,
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

        for (index, screen) in NSScreen.screens.enumerated() {
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            let view = OverlayView(
                profile: profile,
                meeting: meeting,
                snoozeIntervals: snoozeIntervals,
                challenge: challenge,
                onSnooze: snooze,
                onDismiss: dismissAll,
                onFocus: { [weak window] in
                    NSApp.activate(ignoringOtherApps: true)
                    window?.makeKeyAndOrderFront(nil)
                }
            )
            window.contentView = NSHostingView(rootView: view)
            styleOverlay(window, on: screen)
            if index == 0 {
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderFrontRegardless()
            }
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
        announce(meeting)
        // Kiosk-style: cover everything and block escaping to other apps.
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching]

        // Esc always dismisses — the guaranteed escape hatch, even when the Dismiss button
        // is puzzle-gated, so the overlay can never trap the user.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc
                dismissAll()
                return nil
            }
            return event
        }
    }

    private func styleOverlay(_ window: NSWindow, on screen: NSScreen) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.setFrame(screen.frame, display: true)
    }

    /// Ask VoiceOver to speak the alarm as it appears, so it isn't silent for blind users.
    private func announce(_ meeting: Meeting) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: "Meeting alarm. \(meeting.title).",
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }

    func dismiss() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        NSApp.presentationOptions = []
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}
