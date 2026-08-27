import Foundation
@testable import MeetingAlarm
import Testing

@MainActor
@Suite("Store")
struct StoreTests {
    func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)") ?? .standard
    }

    @Test("Arming, snoozing, and settings persist and reload")
    func persists() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        let meeting = Meeting(
            id: "m1", title: "Sync",
            start: Date(timeIntervalSince1970: 4000),
            end: Date(timeIntervalSince1970: 6000),
            sourceKind: .eventKit, accountLabel: nil
        )
        store.arm(meeting, preset: "Gentle Ramp")
        store.setSnooze("m1", at: Date(timeIntervalSince1970: 5000))
        store.syncInterval = 120
        store.snoozeIntervals = [60, 300]

        let reloaded = Store(defaults: defaults)
        #expect(reloaded.armed["m1"]?.presetName == "Gentle Ramp")
        #expect(reloaded.armed["m1"]?.meeting.id == "m1")
        #expect(reloaded.snoozes["m1"] == Date(timeIntervalSince1970: 5000))
        #expect(reloaded.syncInterval == 120)
        #expect(reloaded.snoozeIntervals == [60, 300])
    }

    @Test("prunePastSnoozes drops targets at or before now")
    func prunes() {
        let store = Store(defaults: makeDefaults())
        store.setSnooze("past", at: Date(timeIntervalSince1970: 100))
        store.setSnooze("future", at: Date(timeIntervalSince1970: 10000))
        store.prunePastSnoozes(now: Date(timeIntervalSince1970: 5000))
        #expect(store.snoozes["past"] == nil)
        #expect(store.snoozes["future"] != nil)
    }

    private func meeting(_ id: String, seriesId: String? = nil) -> Meeting {
        Meeting(
            id: id, title: "Event",
            start: Date(timeIntervalSince1970: 4000),
            end: Date(timeIntervalSince1970: 6000),
            sourceKind: .eventKit, accountLabel: nil, seriesId: seriesId
        )
    }

    @Test("Series arming and per-occurrence skips persist and reload")
    func seriesPersists() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        store.armSeries("S1", preset: "Blast")
        store.addSeriesException(seriesId: "S1", occurrenceId: "occ-2")
        let reloaded = Store(defaults: defaults)
        #expect(reloaded.armedSeries["S1"] == "Blast")
        #expect(reloaded.seriesExceptions["S1"]?.contains("occ-2") == true)
    }

    @Test("disarmSeries clears the rule, skips, and materialized occurrences")
    func disarmSeriesClears() {
        let store = Store(defaults: makeDefaults())
        store.armSeries("S1", preset: "Blast")
        _ = store.setMaterializedSeries([
            .init(meeting: meeting("occ-1", seriesId: "S1"), preset: "Blast")
        ])
        store.addSeriesException(seriesId: "S1", occurrenceId: "occ-9")
        #expect(store.armed["occ-1"]?.fromSeries == true)
        store.disarmSeries("S1")
        #expect(store.armedSeries["S1"] == nil)
        #expect(store.seriesExceptions["S1"] == nil)
        #expect(store.armed["occ-1"] == nil)
    }

    @Test("setMaterializedSeries is idempotent and preserves explicit arms")
    func materializeKeepsExplicit() {
        let store = Store(defaults: makeDefaults())
        store.arm(meeting("explicit"), preset: "Gentle Ramp")
        let entries: [SeriesMaterializer.Entry] = [
            .init(meeting: meeting("occ-1", seriesId: "S1"), preset: "Blast")
        ]
        #expect(store.setMaterializedSeries(entries) == true)
        #expect(store.setMaterializedSeries(entries) == false)
        #expect(store.armed["explicit"]?.presetName == "Gentle Ramp")
        #expect(store.armed["occ-1"]?.fromSeries == true)
        #expect(store.setMaterializedSeries([]) == true)
        #expect(store.armed["occ-1"] == nil)
        #expect(store.armed["explicit"] != nil)
    }
}
