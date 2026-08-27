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
        store.armed[meeting.id] != nil
    }

    /// A meeting whose start has passed can't be armed/disarmed (its checkbox is disabled),
    /// preserving the record of whether it was armed.
    func isPast(_ meeting: Meeting) -> Bool {
        meeting.start <= Date()
    }

    func toggleArm(_ meeting: Meeting) {
        guard !isPast(meeting) else { return }
        if isArmed(meeting) {
            store.disarm(meeting.id)
        } else {
            store.arm(meeting, preset: store.defaultPresetName)
        }
        reschedule()
    }

    func setPreset(_ meeting: Meeting, preset: String) {
        guard isArmed(meeting) else { return }
        store.arm(meeting, preset: preset)
        reschedule()
    }
}
