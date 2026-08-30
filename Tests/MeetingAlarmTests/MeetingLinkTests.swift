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

    @Test("A Zoom description with agenda + chat links yields a single join button")
    func zoomDedupesToJoin() {
        let notes = """
        Join Zoom Meeting:
        https://backblaze.zoom.us/j/95995257951?pwd=abc.1&jst=2
        Meeting agenda:
        https://docs.zoom.us/agenda/doc/11b3?from=gsuite
        Chat with Everyone:
        https://backblaze.zoom.us/launch/jc/95995257951
        """
        let urls = MeetingLink.detectAll(explicit: nil, texts: [notes])
        #expect(urls.count == 1)
        #expect(urls.first?.host == "backblaze.zoom.us")
        #expect(urls.first?.path.hasPrefix("/j/") == true)
    }
}
