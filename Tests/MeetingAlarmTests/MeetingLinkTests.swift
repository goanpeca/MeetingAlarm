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

    @Test("Drops a non-http(s) explicit URL from untrusted calendar data")
    func dropsNonWebExplicit() {
        #expect(MeetingLink.detectAll(
            explicit: URL(string: "file:///etc/passwd"), texts: [nil, "no links"]
        ).isEmpty)
        #expect(MeetingLink.detectAll(
            explicit: URL(string: "javascript:alert(1)"), texts: ["just a note"]
        ).isEmpty)
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

    @Test("Zoom links on different hosts/subdomains collapse to one provider button")
    func zoomSubdomainsShareOneProvider() {
        let urls = MeetingLink.detectAll(
            explicit: nil,
            texts: ["https://zoom.us/j/111 or https://us02web.zoom.us/j/222"]
        )
        #expect(urls.count == 1)
    }

    @Test("Meet and Zoom stay separate providers even when each appears on a subdomain")
    func distinctProvidersStaySeparate() {
        let urls = MeetingLink.detectAll(
            explicit: nil,
            texts: ["https://us02web.zoom.us/j/222 and https://meet.google.com/abc-defg-hij"]
        )
        #expect(urls.count == 2)
    }

    @Test("A non-join Zoom docs link alone is not treated as a join link")
    func zoomDocsIsNotAJoin() {
        let urls = MeetingLink.detectAll(
            explicit: nil, texts: ["https://docs.zoom.us/agenda/doc/11b3"]
        )
        // No join link exists, so detection falls back to the single first URL.
        #expect(urls.count == 1)
        #expect(urls.first?.host == "docs.zoom.us")
    }
}
