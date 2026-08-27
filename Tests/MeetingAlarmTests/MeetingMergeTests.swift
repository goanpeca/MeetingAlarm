import Foundation
@testable import MeetingAlarm
import Testing

@Suite("MeetingMerge")
struct MeetingMergeTests {
    func meeting(_ id: String, _ time: TimeInterval) -> Meeting {
        Meeting(
            id: id, title: id,
            start: Date(timeIntervalSince1970: time),
            end: Date(timeIntervalSince1970: time + 60),
            sourceKind: .eventKit, accountLabel: nil
        )
    }

    @Test("Merges accounts, sorts by start then id, keeps cross-account duplicates")
    func merges() {
        let first = [meeting("a2", 200), meeting("a1", 100)]
        let second = [meeting("b1", 150), meeting("b0", 100)]
        let result = MeetingMerge.merged([first, second])
        #expect(result.map(\.id) == ["a1", "b0", "b1", "a2"])
    }
}
