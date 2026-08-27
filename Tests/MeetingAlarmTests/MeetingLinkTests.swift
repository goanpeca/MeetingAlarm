import Foundation
@testable import MeetingAlarm
import Testing

@Suite("MeetingLink")
struct MeetingLinkTests {
    @Test("Prefers a known video-conferencing link over a plain one")
    func prefersVideoHost() {
        let url = MeetingLink.detect(
            explicit: URL(string: "https://example.com/agenda"),
            texts: ["Join at https://meet.google.com/abc-defg-hij"]
        )
        #expect(url?.host == "meet.google.com")
    }

    @Test("Falls back to the explicit URL when no preferred link is present")
    func fallsBackToExplicit() {
        let url = MeetingLink.detect(
            explicit: URL(string: "https://example.com/room"),
            texts: [nil, "no links here"]
        )
        #expect(url?.absoluteString == "https://example.com/room")
    }

    @Test("Finds the first URL in free text when there is no explicit link")
    func findsInText() {
        let url = MeetingLink.detect(explicit: nil, texts: ["see https://whereby.com/team"])
        #expect(url?.host == "whereby.com")
    }

    @Test("Returns nil when there is no link anywhere")
    func noLink() {
        #expect(MeetingLink.detect(explicit: nil, texts: ["just a note", nil]) == nil)
    }
}
