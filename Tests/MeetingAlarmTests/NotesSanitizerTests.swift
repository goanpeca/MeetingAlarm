import Foundation
@testable import MeetingAlarm
import Testing

@Suite("NotesSanitizer")
struct NotesSanitizerTests {
    @Test("Strips the Google Meet boilerplate block after the separator")
    func stripsMeetBlock() {
        let raw = "Something super cool!<br>"
            + "-::~:~::~:~:~:~::- Únase con Google Meet: https://meet.google.com/abc "
            + "No edites esta sección. -::~:~::-"
        #expect(NotesSanitizer.clean(raw) == "Something super cool!")
    }

    @Test("Keeps a plain description untouched")
    func keepsPlain() {
        #expect(NotesSanitizer.clean("Just a normal note") == "Just a normal note")
    }

    @Test("Returns nil for empty, nil, or boilerplate-only notes")
    func nilForEmpty() {
        #expect(NotesSanitizer.clean(nil) == nil)
        #expect(NotesSanitizer.clean("-::~:~::~:~::- boilerplate only") == nil)
    }
}
