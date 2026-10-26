import Foundation
@testable import MeetingAlarm
import Testing

/// Each mutator is exercised in isolation — one mutation, then a reload from the same
/// UserDefaults — so a dropped `save()` (or a skipped secondary effect like clearing an
/// override) changes the reloaded state and fails the test. This is what kills the
/// `RemoveSideEffects` mutants that a same-instance assertion would miss.
@MainActor
@Suite("Store persistence")
struct StorePersistenceTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)") ?? .standard
    }

    private func meeting(
        _ id: String,
        seriesId: String? = nil,
        start: TimeInterval = 4000
    ) -> Meeting {
        Meeting(
            id: id, title: "Event",
            start: Date(timeIntervalSince1970: start),
            end: Date(timeIntervalSince1970: start + 2000),
            sourceKind: .eventKit, accountLabel: nil, seriesId: seriesId
        )
    }

    // MARK: Snoozes

    @Test("setSnooze persists")
    func setSnoozePersists() {
        let defaults = makeDefaults()
        Store(defaults: defaults).setSnooze("m1", at: Date(timeIntervalSince1970: 5000))
        #expect(Store(defaults: defaults).snoozes["m1"] == Date(timeIntervalSince1970: 5000))
    }

    @Test("clearSnooze persists the removal")
    func clearSnoozePersists() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        store.setSnooze("m1", at: Date(timeIntervalSince1970: 5000))
        store.clearSnooze("m1")
        #expect(Store(defaults: defaults).snoozes["m1"] == nil)
    }

    @Test("prunePastSnoozes persists the surviving set")
    func prunePersists() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        store.setSnooze("past", at: Date(timeIntervalSince1970: 100))
        store.setSnooze("future", at: Date(timeIntervalSince1970: 10000))
        store.prunePastSnoozes(now: Date(timeIntervalSince1970: 5000))
        let reloaded = Store(defaults: defaults)
        #expect(reloaded.snoozes["past"] == nil)
        #expect(reloaded.snoozes["future"] != nil)
    }

    @Test("prunePastSnoozes drops a snooze due exactly now (boundary is exclusive)")
    func pruneBoundary() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        let now = Date(timeIntervalSince1970: 5000)
        store.setSnooze("exactly-now", at: now)
        store.setSnooze("just-after", at: now.addingTimeInterval(1))
        store.prunePastSnoozes(now: now)
        #expect(store.snoozes["exactly-now"] == nil)
        #expect(store.snoozes["just-after"] != nil)
        #expect(Store(defaults: defaults).snoozes["exactly-now"] == nil)
    }

    // MARK: Per-occurrence arming

    @Test("arm persists and un-handles the occurrence")
    func armPersistsAndUnhandles() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        store.markHandled("m1")
        store.arm(meeting("m1"), preset: "Blast")
        #expect(!store.handled.contains("m1"))
        #expect(Store(defaults: defaults).armed["m1"]?.presetName == "Blast")
    }

    @Test("disarm persists removal of the arm, its override, and handled flag")
    func disarmPersists() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        store.arm(meeting("m1"), preset: "Blast")
        store.setOverrides("m1", AlarmOverrides(color: .red))
        store.markHandled("m1")
        store.disarm("m1")
        #expect(!store.handled.contains("m1"))
        let reloaded = Store(defaults: defaults)
        #expect(reloaded.armed["m1"] == nil)
        #expect(reloaded.armOverrides["m1"] == nil)
    }

    @Test("exclude persists and clears arm, snooze, override, and handled")
    func excludePersists() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        store.arm(meeting("m1"), preset: "Blast")
        store.setSnooze("m1", at: Date(timeIntervalSince1970: 5000))
        store.setOverrides("m1", AlarmOverrides(color: .red))
        store.markHandled("m1")
        store.exclude("m1")
        #expect(!store.handled.contains("m1"))
        let reloaded = Store(defaults: defaults)
        #expect(reloaded.excludedMeetingIds.contains("m1"))
        #expect(reloaded.armed["m1"] == nil)
        #expect(reloaded.snoozes["m1"] == nil)
        #expect(reloaded.armOverrides["m1"] == nil)
    }

    @Test("include persists the arm and drops the exclusion")
    func includePersists() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        store.exclude("m1")
        store.markHandled("m1")
        store.include(meeting("m1"), preset: "Gentle Ramp")
        #expect(!store.handled.contains("m1"))
        let reloaded = Store(defaults: defaults)
        #expect(!reloaded.excludedMeetingIds.contains("m1"))
        #expect(reloaded.armed["m1"]?.presetName == "Gentle Ramp")
    }

    @Test("markHandled persists")
    func markHandledPersists() {
        let defaults = makeDefaults()
        Store(defaults: defaults).markHandled("m1")
        #expect(Store(defaults: defaults).handled.contains("m1"))
    }

    @Test("updateArmed persists the new snapshot and un-handles")
    func updateArmedPersists() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        store.arm(meeting("m1", start: 4000), preset: "Blast")
        store.markHandled("m1")
        store.updateArmed(meeting("m1", start: 9000))
        #expect(!store.handled.contains("m1"))
        let reloaded = Store(defaults: defaults)
        #expect(reloaded.armed["m1"]?.meeting.start == Date(timeIntervalSince1970: 9000))
    }

    @Test("updateArmed is a no-op for an unarmed occurrence")
    func updateArmedNoOpWhenUnarmed() {
        let store = Store(defaults: makeDefaults())
        store.updateArmed(meeting("ghost"))
        #expect(store.armed["ghost"] == nil)
    }

    @Test("setOverrides persists and clears when emptied")
    func setOverridesPersists() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        store.setOverrides("m1", AlarmOverrides(color: .red))
        #expect(Store(defaults: defaults).armOverrides["m1"]?.color == .red)
        store.setOverrides("m1", AlarmOverrides())
        #expect(Store(defaults: defaults).armOverrides["m1"] == nil)
    }

    @Test("clearArmChoices persists the reset")
    func clearArmChoicesPersists() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        store.arm(meeting("m1"), preset: "Blast")
        store.armSeries("S1", preset: "Blast")
        store.exclude("m2")
        store.disarmSeries("S2")
        store.clearArmChoices()
        let reloaded = Store(defaults: defaults)
        #expect(reloaded.armed.isEmpty)
        #expect(reloaded.armedSeries.isEmpty)
        #expect(reloaded.excludedMeetingIds.isEmpty)
        #expect(reloaded.excludedSeriesIds.isEmpty)
        #expect(reloaded.seriesExceptions.isEmpty)
    }

    // MARK: Series arming

    @Test("armSeries persists and clears that series' prior skips and exclusions")
    func armSeriesPersists() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        store.disarmSeries("S1")
        store.addSeriesException(seriesId: "S1", occurrenceId: "occ")
        store.armSeries("S1", preset: "Blast")
        let reloaded = Store(defaults: defaults)
        #expect(reloaded.armedSeries["S1"] == "Blast")
        #expect(reloaded.seriesExceptions["S1"] == nil)
        #expect(!reloaded.excludedMeetingIds.contains("occ"))
        #expect(!reloaded.excludedSeriesIds.contains("S1"))
    }

    @Test("disarmSeries persists the opt-out and clears the series' occurrences")
    func disarmSeriesPersists() {
        let defaults = makeDefaults()
        let store = Store(defaults: defaults)
        store.armSeries("S1", preset: "Blast")
        store.arm(meeting("occ-1", seriesId: "S1"), preset: "Blast")
        store.setSnooze("occ-1", at: Date(timeIntervalSince1970: 5000))
        store.setOverrides("occ-1", AlarmOverrides(color: .red))
        store.markHandled("occ-1")
        store.setSeriesOverrides("S1", AlarmOverrides(color: .red))
        store.disarmSeries("S1")
        #expect(!store.handled.contains("occ-1"))
        let reloaded = Store(defaults: defaults)
        #expect(reloaded.excludedSeriesIds.contains("S1"))
        #expect(reloaded.armedSeries["S1"] == nil)
        #expect(reloaded.seriesOverrides["S1"] == nil)
        #expect(reloaded.armed["occ-1"] == nil)
        #expect(reloaded.snoozes["occ-1"] == nil)
        #expect(reloaded.armOverrides["occ-1"] == nil)
    }

    @Test("addSeriesException persists both the skip and the occurrence exclusion")
    func addSeriesExceptionPersists() {
        let defaults = makeDefaults()
        Store(defaults: defaults).addSeriesException(seriesId: "S1", occurrenceId: "occ")
        let reloaded = Store(defaults: defaults)
        #expect(reloaded.seriesExceptions["S1"]?.contains("occ") == true)
        #expect(reloaded.excludedMeetingIds.contains("occ"))
    }
}
