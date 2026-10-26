import Foundation
@testable import MeetingAlarm
import Testing

@Suite("OverlayKey")
struct OverlayKeyTests {
    @Test("Esc dismisses the overlay under every dismiss challenge (never trap the user)")
    func escAlwaysDismisses() {
        #expect(!DismissChallenge.allCases.isEmpty)
        for challenge in DismissChallenge.allCases {
            #expect(OverlayKey.dismisses(keyCode: OverlayKey.escapeKeyCode, challenge: challenge))
        }
    }

    @Test("The escape key code is macOS virtual key 53")
    func escapeKeyCode() {
        #expect(OverlayKey.escapeKeyCode == 53)
    }

    @Test("Other keys never dismiss, so typing into the puzzle field is unaffected")
    func otherKeysPassThrough() {
        // Return (36), Space (49), a letter (0), Delete (51), and the key just beside Esc.
        for code: UInt16 in [36, 49, 0, 51, 52, 54] {
            for challenge in DismissChallenge.allCases {
                #expect(!OverlayKey.dismisses(keyCode: code, challenge: challenge))
            }
        }
    }
}
