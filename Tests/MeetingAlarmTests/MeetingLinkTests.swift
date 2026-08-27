import Foundation
@testable import MeetingAlarm
import Testing

@Suite("MeetingLink")
struct MeetingLinkTests {
    @Test("Prefers known video links and drops a non-preferred explicit one")
    func prefersVideoHost() {
        let urls = MeetingLink.detectAll(
            explicit: URL(string: "https://example.com/agenda"),
            texts: ["Join at https://meet.google.com/abc-defg-hij"]
        )
        #expect(urls.map(\.host) == ["meet.google.com"])
    }

    @Test("Returns BOTH links when Meet and Zoom are present")
    func returnsBoth() {
        let urls = MeetingLink.detectAll(
            explicit: nil,
            texts: ["meet https://meet.google.com/x and zoom https://zoom.us/j/1"]
        )
        #expect(urls.count == 2)
        #expect(urls.contains { $0.host == "meet.google.com" })
        #expect(urls.contains { $0.host == "zoom.us" })
    }

    @Test("Falls back to the explicit URL when no preferred link is present")
    func fallsBackToExplicit() {
        let urls = MeetingLink.detectAll(
            explicit: URL(string: "https://example.com/room"),
            texts: [nil, "no links here"]
        )
        #expect(urls.map(\.absoluteString) == ["https://example.com/room"])
    }

    @Test("Returns empty when there is no link anywhere")
    func noLink() {
        #expect(MeetingLink.detectAll(explicit: nil, texts: ["just a note", nil]).isEmpty)
    }
}
