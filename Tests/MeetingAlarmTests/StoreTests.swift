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
        store.autoArm = true

        let reloaded = Store(defaults: defaults)
        #expect(reloaded.armed["m1"]?.presetName == "Gentle Ramp")
        #expect(reloaded.armed["m1"]?.meeting.id == "m1")
        #expect(reloaded.snoozes["m1"] == Date(timeIntervalSince1970: 5000))
        #expect(reloaded.syncInterval == 120)
        #expect(reloaded.snoozeIntervals == [60, 300])
        #expect(reloaded.autoArm == true)
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

    @Test("A pre-recurring saved snapshot still decodes; new fields take defaults")
    func decodesLegacySnapshot() {
        let defaults = makeDefaults()
        // Frozen v1 blob: no fromSeries / seriesId / armedSeries / sound+appearance keys.
        let legacy = """
        {
          "armed": {
            "eventkit:E1:2026-08-26": {
              "presetName": "Blast",
              "meeting": {
                "id": "eventkit:E1:2026-08-26", "title": "Standup",
                "start": 776000000, "end": 776001800,
                "sourceKind": "eventKit", "accountLabel": "Work",
                "joinURLs": [], "attendees": ["Alice"]
              }
            }
          },
          "snoozes": {}, "activeSource": "eventKit",
          "defaultPresetName": "Gentle Ramp", "syncInterval": 300,
          "snoozeIntervals": [60, 300, 600]
        }
        """
        defaults.set(Data(legacy.utf8), forKey: "state.v1")

        let store = Store(defaults: defaults)
        let entry = store.armed["eventkit:E1:2026-08-26"]
        #expect(entry?.presetName == "Blast")
        #expect(entry?.meeting.title == "Standup")
        #expect(entry?.meeting.seriesId == nil)
        #expect(store.defaultPresetName == "Gentle Ramp")
        #expect(store.soundEnabled == true)
        #expect(store.alarmSound == .jewelDrop)
        #expect(store.armedSeries.isEmpty)
        #expect(store.handled.isEmpty)
        #expect(store.excludedMeetingIds.isEmpty)
        #expect(store.excludedSeriesIds.isEmpty)
        #expect(store.autoArm == false)
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

    @Test("Re-arming a series clears prior per-occurrence skips and their exclusions")
    func rearmSeriesClearsSkips() {
        let store = Store(defaults: makeDefaults())
        store.armSeries("S1", preset: "Blast")
        store.addSeriesException(seriesId: "S1", occurrenceId: "occ-2")
        #expect(store.excludedMeetingIds.contains("occ-2"))
        store.armSeries("S1", preset: "Blast")
        #expect(store.seriesExceptions["S1"] == nil)
        #expect(!store.excludedMeetingIds.contains("occ-2"))
    }

    @Test("clearArmChoices drops arms, series, and exclusions but keeps overrides")
    func clearArmChoicesResets() {
        let store = Store(defaults: makeDefaults())
        store.arm(meeting("m1"), preset: "Blast")
        store.armSeries("S1", preset: "Blast")
        store.exclude("m2")
        store.disarmSeries("S2")
        store.setOverrides("m1", AlarmOverrides(color: .red))
        store.clearArmChoices()
        #expect(store.armed.isEmpty)
        #expect(store.armedSeries.isEmpty)
        #expect(store.excludedMeetingIds.isEmpty)
        #expect(store.excludedSeriesIds.isEmpty)
        #expect(store.seriesExceptions.isEmpty)
        #expect(store.armOverrides["m1"]?.color == .red)
    }

    @Test("Excluded meetings and series persist so default alarms stay opted out")
    func exclusionsPersist() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        store.exclude("one-off")
        store.disarmSeries("S1")

        let reloaded = Store(defaults: defaults)
        #expect(reloaded.excludedMeetingIds.contains("one-off"))
        #expect(reloaded.excludedSeriesIds.contains("S1"))
    }

    @Test("disarmSeries clears the rule, skips, overrides, and explicit occurrence arms")
    func disarmSeriesClears() {
        let store = Store(defaults: makeDefaults())
        store.armSeries("S1", preset: "Blast")
        store.arm(meeting("occ-1", seriesId: "S1"), preset: "Blast")
        store.addSeriesException(seriesId: "S1", occurrenceId: "occ-9")
        store.setSeriesOverrides("S1", AlarmOverrides(color: .red))
        #expect(store.armed["occ-1"] != nil)
        store.disarmSeries("S1")
        #expect(store.armedSeries["S1"] == nil)
        #expect(store.seriesExceptions["S1"] == nil)
        #expect(store.seriesOverrides["S1"] == nil)
        #expect(store.armed["occ-1"] == nil)
    }

    @Test("Series overrides persist, reload, and clear when emptied")
    func seriesOverridesPersist() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        store.setSeriesOverrides("S1", AlarmOverrides(color: .red, sound: .silent))
        #expect(Store(defaults: defaults).seriesOverrides["S1"]
            == AlarmOverrides(color: .red, sound: .silent))
        store.setSeriesOverrides("S1", AlarmOverrides())
        #expect(store.seriesOverrides["S1"] == nil)
        #expect(Store(defaults: defaults).seriesOverrides["S1"] == nil)
    }
}
