import Foundation
@testable import MeetingAlarm
import Testing

@Suite("ScopePrompt")
struct ScopePromptTests {
    private func meeting() -> Meeting {
        Meeting(
            id: "m1", title: "Event",
            start: Date(timeIntervalSince1970: 4000),
            end: Date(timeIntervalSince1970: 6000),
            sourceKind: .eventKit, accountLabel: nil
        )
    }

    @Test("id encodes the meeting id and the arm/disarm kind distinctly")
    func idEncodesKind() {
        let arm = ScopePrompt(meeting: meeting(), kind: .arm)
        let disarm = ScopePrompt(meeting: meeting(), kind: .disarm)
        #expect(arm.id == "m1:arm")
        #expect(disarm.id == "m1:disarm")
        #expect(arm.id != disarm.id)
    }
}
