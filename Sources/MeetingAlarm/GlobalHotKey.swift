import AppKit
import Carbon.HIToolbox

extension Notification.Name {
    /// Posted (on the main queue) when the global summon hot key is pressed.
    static let meetingAlarmSummon = Notification.Name("meetingAlarmSummon")
}

/// A single system-wide hot key via Carbon's `RegisterEventHotKey`, which — unlike an
/// `NSEvent` global monitor — needs no Accessibility permission. On press it posts
/// `.meetingAlarmSummon`; the panel controller listens for it. Only one is registered, so
/// the handler can post unconditionally.
final class GlobalHotKey {
    private var ref: EventHotKeyRef?

    init(keyCode: UInt32, modifiers: UInt32) {
        _ = GlobalHotKey.installHandlerOnce
        let id = EventHotKeyID(signature: 0x4D41_4C4D, id: 1) // 'MALM'
        RegisterEventHotKey(keyCode, modifiers, id, GetEventDispatcherTarget(), 0, &ref)
    }

    deinit {
        if let ref {
            UnregisterEventHotKey(ref)
        }
    }

    private static let installHandlerOnce: Void = {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetEventDispatcherTarget(), { _, _, _ -> OSStatus in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .meetingAlarmSummon, object: nil)
            }
            return noErr
        }, 1, &spec, nil, nil)
    }()
}
