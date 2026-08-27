import Foundation
@testable import MeetingAlarm
import Testing

@Suite("SeriesMaterializer")
struct SeriesMaterializerTests {
    private func meeting(_ id: String, seriesId: String?) -> Meeting {
        Meeting(
            id: id, title: "E",
            start: Date(timeIntervalSince1970: 1000),
            end: Date(timeIntervalSince1970: 2000),
            sourceKind: .eventKit, accountLabel: nil, seriesId: seriesId
        )
    }

    @Test("Arms only occurrences of an armed series, skipping non-series and other series")
    func armsMatching() {
        let upcoming = [
            meeting("a1", seriesId: "S1"),
            meeting("b1", seriesId: "S2"),
            meeting("c1", seriesId: nil)
        ]
        let entries = SeriesMaterializer.occurrencesToArm(
            upcoming: upcoming, armedSeries: ["S1": "Blast"],
            exceptions: [:], explicitlyArmed: [], handled: []
        )
        #expect(entries.map(\.meeting.id) == ["a1"])
        #expect(entries.first?.preset == "Blast")
    }

    @Test("Skips exceptions, explicitly-armed, and already-handled occurrences")
    func skipsExcluded() {
        let upcoming = [
            meeting("a1", seriesId: "S1"),
            meeting("a2", seriesId: "S1"),
            meeting("a3", seriesId: "S1"),
            meeting("a4", seriesId: "S1")
        ]
        let entries = SeriesMaterializer.occurrencesToArm(
            upcoming: upcoming, armedSeries: ["S1": "Blast"],
            exceptions: ["S1": ["a2"]], explicitlyArmed: ["a3"], handled: ["a4"]
        )
        #expect(entries.map(\.meeting.id) == ["a1"])
    }
}
