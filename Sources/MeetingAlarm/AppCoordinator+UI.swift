import Foundation

/// Day navigation and per-meeting arming, split from the main coordinator to keep files
/// focused (and under the file-size limit).
extension AppCoordinator {
    // MARK: Day navigation

    func today() {
        setDay(Date())
    }

    func nextDay() {
        setDay(DayWindow.shift(selectedDay, byDays: 1, calendar: calendar))
    }

    func prevDay() {
        setDay(DayWindow.shift(selectedDay, byDays: -1, calendar: calendar))
    }

    private func setDay(_ day: Date) {
        selectedDay = day
        Task { await sync() }
    }

    // MARK: Arming

    func isArmed(_ meeting: Meeting) -> Bool {
        store.armed[meeting.id] != nil || isArmedViaSeries(meeting)
    }

    /// Armed because its whole series is armed (and this occurrence isn't a skipped one).
    func isArmedViaSeries(_ meeting: Meeting) -> Bool {
        guard let seriesId = meeting.seriesId, store.armedSeries[seriesId] != nil else {
            return false
        }
        return !(store.seriesExceptions[seriesId]?.contains(meeting.id) ?? false)
    }

    func isRecurring(_ meeting: Meeting) -> Bool {
        meeting.seriesId != nil
    }

    /// A meeting whose start has passed can't be armed/disarmed (its checkbox is disabled),
    /// preserving the record of whether it was armed.
    func isPast(_ meeting: Meeting) -> Bool {
        meeting.start <= Date()
    }

    /// The preset that will fire for a meeting, whether armed on its own or via its series.
    func presetName(for meeting: Meeting) -> String {
        if isArmedViaSeries(meeting), let seriesId = meeting.seriesId {
            return store.armedSeries[seriesId] ?? store.defaultPresetName
        }
        return store.armed[meeting.id]?.presetName ?? store.defaultPresetName
    }

    /// Checkbox entry point: a recurring event opens the "this event / all in series" prompt;
    /// a one-off (or a recurring event armed on its own) toggles directly.
    func requestArmToggle(_ meeting: Meeting) {
        guard !isPast(meeting) else { return }
        let armed = isArmed(meeting)
        if isRecurring(meeting), !armed || isArmedViaSeries(meeting) {
            scopePrompt = ScopePrompt(meeting: meeting, kind: armed ? .disarm : .arm)
        } else {
            toggleArm(meeting)
        }
    }

    /// Plain (non-prompting) arm/disarm of a single occurrence. Recurring events route
    /// through the scoped methods below via the row's "This event / All in series" prompt.
    func toggleArm(_ meeting: Meeting) {
        guard !isPast(meeting) else { return }
        if store.armed[meeting.id] != nil {
            store.disarm(meeting.id)
        } else {
            store.arm(meeting, preset: store.defaultPresetName)
        }
        reschedule()
    }

    func armOccurrence(_ meeting: Meeting) {
        guard !isPast(meeting) else { return }
        store.arm(meeting, preset: store.defaultPresetName)
        reschedule()
    }

    func armSeries(_ meeting: Meeting) {
        guard let seriesId = meeting.seriesId else { return }
        store.armSeries(seriesId, preset: store.defaultPresetName)
        Task { await materializeSeries(force: true) }
    }

    /// "Skip just this one" occurrence of an armed series.
    func skipOccurrence(_ meeting: Meeting) {
        guard let seriesId = meeting.seriesId else { return }
        store.addSeriesException(seriesId: seriesId, occurrenceId: meeting.id)
        reschedule()
    }

    func disarmSeries(_ meeting: Meeting) {
        guard let seriesId = meeting.seriesId else { return }
        store.disarmSeries(seriesId)
        reschedule()
    }

    func setPreset(_ meeting: Meeting, preset: String) {
        if isArmedViaSeries(meeting), let seriesId = meeting.seriesId {
            store.armSeries(seriesId, preset: preset)
            Task { await materializeSeries(force: true) }
        } else if store.armed[meeting.id] != nil {
            store.arm(meeting, preset: preset)
            reschedule()
        }
    }
}
