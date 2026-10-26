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

    @Test("Equal-start meetings break the tie by id, independent of account order")
    func tieBreaksById() {
        // Both start at the same instant but arrive out of id order (and reversed between
        // accounts). Only a (start, id) sort yields id order both ways — a start-only sort
        // leaves them in fetch order, so this fails a sort that ignores the id tie-breaker.
        let first = [meeting("z", 100)]
        let second = [meeting("a", 100)]
        #expect(MeetingMerge.merged([first, second]).map(\.id) == ["a", "z"])
        #expect(MeetingMerge.merged([second, first]).map(\.id) == ["a", "z"])
    }
}
