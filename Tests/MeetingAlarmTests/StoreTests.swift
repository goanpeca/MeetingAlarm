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
}
