import Foundation
@testable import MeetingAlarm
import Testing

@Suite("DefaultArming")
struct DefaultArmingTests {
    private func meeting(_ id: String, seriesId: String? = nil) -> Meeting {
        Meeting(
            id: id, title: "Event",
            start: Date(timeIntervalSince1970: 4000),
            end: Date(timeIntervalSince1970: 6000),
            sourceKind: .eventKit, accountLabel: nil, seriesId: seriesId
        )
    }

    private func isArmed(
        _ event: Meeting,
        autoArm: Bool,
        explicit: Set<String> = [],
        armedSeries: Set<String> = [],
        excludedMeetings: Set<String> = [],
        excludedSeries: Set<String> = [],
        exceptions: [String: Set<String>] = [:]
    ) -> Bool {
        DefaultArming.isArmed(
            meeting: event, autoArm: autoArm, explicitlyArmedIds: explicit,
            armedSeriesIds: armedSeries, excludedMeetingIds: excludedMeetings,
            excludedSeriesIds: excludedSeries, seriesExceptions: exceptions
        )
    }

    @Test("Auto-arm on: every meeting armed unless explicitly opted out")
    func autoArmDefaultsAndExclusion() {
        let event = meeting("default")
        #expect(isArmed(event, autoArm: true))
        #expect(!isArmed(event, autoArm: true, excludedMeetings: ["default"]))
    }

    @Test("Auto-arm off: nothing armed unless explicitly chosen")
    func optInDefaults() {
        let oneOff = meeting("one-off")
        #expect(!isArmed(oneOff, autoArm: false))
        #expect(isArmed(oneOff, autoArm: false, explicit: ["one-off"]))

        let occurrence = meeting("occ", seriesId: "series")
        #expect(!isArmed(occurrence, autoArm: false))
        #expect(isArmed(occurrence, autoArm: false, armedSeries: ["series"]))
    }

    @Test("An explicit arm overrides a disabled series (auto-arm on)")
    func explicitOccurrenceOverridesSeriesExclusion() {
        let event = meeting("occurrence", seriesId: "series")
        #expect(!isArmed(event, autoArm: true, excludedSeries: ["series"]))
        #expect(isArmed(event, autoArm: true, explicit: ["occurrence"], excludedSeries: ["series"]))
    }

    @Test("An armed series still honors a per-occurrence skip, in either mode")
    func armedSeriesHonorsSkip() {
        let event = meeting("skip", seriesId: "series")
        for autoArm in [true, false] {
            #expect(isArmed(event, autoArm: autoArm, armedSeries: ["series"]))
            #expect(!isArmed(
                event, autoArm: autoArm, armedSeries: ["series"],
                exceptions: ["series": ["skip"]]
            ))
        }
    }

    @Test("Occurrence opt-outs always win, including within an armed series")
    func occurrenceExclusionWins() {
        let event = meeting("skip", seriesId: "series")
        #expect(!isArmed(
            event, autoArm: true, explicit: ["skip"], excludedMeetings: ["skip"]
        ))
    }
}
