import Foundation
@testable import MeetingAlarm
import Testing

@Suite("DefaultArming")
struct DefaultArmingTests {
    private func meeting(_ id: String, seriesId: String? = nil) -> Meeting {
        Meeting(
            id: id, title: "Event",
            start: Date(timeIntervalSince1970: 4_000),
            end: Date(timeIntervalSince1970: 6_000),
            sourceKind: .eventKit, accountLabel: nil, seriesId: seriesId
        )
    }

    @Test("Arms every meeting unless it has an explicit opt-out")
    func defaultsAndOccurrenceExclusion() {
        let event = meeting("default")
        #expect(DefaultArming.isArmed(
            meeting: event, explicitlyArmedIds: [], excludedMeetingIds: [],
            excludedSeriesIds: [], seriesExceptions: [:]
        ))
        #expect(!DefaultArming.isArmed(
            meeting: event, explicitlyArmedIds: [], excludedMeetingIds: ["default"],
            excludedSeriesIds: [], seriesExceptions: [:]
        ))
    }

    @Test("An explicit occurrence can override a disabled series")
    func explicitOccurrenceOverridesSeriesExclusion() {
        let event = meeting("occurrence", seriesId: "series")
        #expect(!DefaultArming.isArmed(
            meeting: event, explicitlyArmedIds: [], excludedMeetingIds: [],
            excludedSeriesIds: ["series"], seriesExceptions: [:]
        ))
        #expect(DefaultArming.isArmed(
            meeting: event, explicitlyArmedIds: ["occurrence"], excludedMeetingIds: [],
            excludedSeriesIds: ["series"], seriesExceptions: [:]
        ))
    }

    @Test("Occurrence opt-outs always win, including within an armed series")
    func occurrenceExclusionWins() {
        let event = meeting("skip", seriesId: "series")
        #expect(!DefaultArming.isArmed(
            meeting: event, explicitlyArmedIds: ["skip"], excludedMeetingIds: ["skip"],
            excludedSeriesIds: [], seriesExceptions: [:]
        ))
    }

    @Test("Legacy series skips remain excluded after moving to default-on alarms")
    func legacySeriesExceptionRemainsExcluded() {
        let event = meeting("skip", seriesId: "series")
        #expect(!DefaultArming.isArmed(
            meeting: event, explicitlyArmedIds: [], excludedMeetingIds: [],
            excludedSeriesIds: [], seriesExceptions: ["series": ["skip"]]
        ))
    }
}
