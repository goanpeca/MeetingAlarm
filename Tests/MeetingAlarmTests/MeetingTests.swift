import Foundation
@testable import MeetingAlarm
import Testing

@Suite("Meeting")
struct MeetingTests {
    @Test("Meeting round-trips through Codable and preserves occurrence identity")
    func codableRoundTrip() throws {
        let meeting = Meeting(
            id: "evt-1#2026-08-26T09:00:00Z",
            title: "Standup",
            start: Date(timeIntervalSince1970: 1_756_200_000),
            end: Date(timeIntervalSince1970: 1_756_201_800),
            sourceKind: .google
        )
        let data = try JSONEncoder().encode(meeting)
        let decoded = try JSONDecoder().decode(Meeting.self, from: data)
        #expect(decoded == meeting)
        #expect(decoded.id == meeting.id)
    }
}
