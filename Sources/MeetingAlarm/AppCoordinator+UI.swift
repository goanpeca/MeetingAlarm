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
        DefaultArming.isArmed(
            meeting: meeting,
            autoArm: store.autoArm,
            explicitlyArmedIds: Set(store.armed.keys),
            armedSeriesIds: Set(store.armedSeries.keys),
            excludedMeetingIds: store.excludedMeetingIds,
            excludedSeriesIds: store.excludedSeriesIds,
            seriesExceptions: store.seriesExceptions
        )
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

    /// Checkbox entry point: recurring events always offer "this event / all in series";
    /// one-offs toggle directly. Meetings are otherwise armed by default.
    func requestArmToggle(_ meeting: Meeting) {
        guard !isPast(meeting) else { return }
        let armed = isArmed(meeting)
        if isRecurring(meeting) {
            scopePrompt = ScopePrompt(meeting: meeting, kind: armed ? .disarm : .arm)
        } else {
            toggleArm(meeting)
        }
    }

    /// Plain (non-prompting) opt-in/opt-out of a single occurrence. Recurring events route
    /// through the scoped methods below via the row's "This event / All in series" prompt.
    func toggleArm(_ meeting: Meeting) {
        guard !isPast(meeting) else { return }
        if isArmed(meeting) {
            store.exclude(meeting.id)
        } else {
            store.include(meeting, preset: store.defaultPresetName)
        }
        reschedule()
    }

    func armOccurrence(_ meeting: Meeting) {
        guard !isPast(meeting) else { return }
        store.include(meeting, preset: store.defaultPresetName)
        reschedule()
    }

    func armSeries(_ meeting: Meeting) {
        guard let seriesId = meeting.seriesId else { return }
        store.include(meeting, preset: store.defaultPresetName)
        store.armSeries(seriesId, preset: store.defaultPresetName)
        materializeSeries()
        reschedule()
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

    // MARK: Per-meeting overrides

    /// Whether an override applies to just this occurrence or the whole recurring series —
    /// the "this event / all in the series" choice, mirroring arm/disarm.
    enum OverrideScope: Equatable { case occurrence, series }

    /// The overrides that actually fire for this meeting: its own occurrence override layered
    /// over its series override, falling through to the global settings. Also drives the row
    /// swatch and the gear's filled state.
    func overrides(for meeting: Meeting) -> AlarmOverrides {
        let occurrence = store.armOverrides[meeting.id] ?? AlarmOverrides()
        guard let seriesId = meeting.seriesId,
              let series = store.seriesOverrides[seriesId] else { return occurrence }
        return occurrence.layered(over: series)
    }

    /// The raw override stored at one scope (not merged) — what the editor shows and edits so
    /// each toggle reflects exactly that scope's stored value.
    func overrides(for meeting: Meeting, scope: OverrideScope) -> AlarmOverrides {
        switch scope {
        case .occurrence:
            return store.armOverrides[meeting.id] ?? AlarmOverrides()
        case .series:
            guard let seriesId = meeting.seriesId else { return AlarmOverrides() }
            return store.seriesOverrides[seriesId] ?? AlarmOverrides()
        }
    }

    /// Whether this meeting's series already has an override (so the editor can default the
    /// scope to "all in the series").
    func hasSeriesOverride(_ meeting: Meeting) -> Bool {
        guard let seriesId = meeting.seriesId else { return false }
        return store.seriesOverrides[seriesId] != nil
    }

    /// The alarm color this meeting will actually fire with (its override, else the global).
    func effectiveColor(for meeting: Meeting) -> RGBAColor {
        overrides(for: meeting).color ?? store.alarmColor
    }

    /// Override (or clear, when `color` is nil) the alarm color at the chosen scope.
    func setColorOverride(_ meeting: Meeting, color: RGBAColor?, scope: OverrideScope) {
        var current = overrides(for: meeting, scope: scope)
        current.color = color
        writeOverrides(meeting, current, scope: scope)
    }

    /// Override (or clear, when `sound` is nil) the alarm sound at the chosen scope.
    func setSoundOverride(_ meeting: Meeting, sound: SoundOverride?, scope: OverrideScope) {
        var current = overrides(for: meeting, scope: scope)
        current.sound = sound
        writeOverrides(meeting, current, scope: scope)
    }

    /// Clear both overrides at the chosen scope ("reset to global").
    func clearOverrides(_ meeting: Meeting, scope: OverrideScope) {
        writeOverrides(meeting, AlarmOverrides(), scope: scope)
    }

    private func writeOverrides(
        _ meeting: Meeting,
        _ overrides: AlarmOverrides,
        scope: OverrideScope
    ) {
        switch scope {
        case .occurrence:
            store.setOverrides(meeting.id, overrides)
        case .series:
            guard let seriesId = meeting.seriesId else { return }
            store.setSeriesOverrides(seriesId, overrides)
        }
        reschedule()
    }

    func setPreset(_ meeting: Meeting, preset: String) {
        if isArmedViaSeries(meeting), let seriesId = meeting.seriesId {
            store.armSeries(seriesId, preset: preset)
            materializeSeries()
            reschedule()
        } else if store.armed[meeting.id] != nil {
            store.arm(meeting, preset: preset)
            reschedule()
        }
    }
}
