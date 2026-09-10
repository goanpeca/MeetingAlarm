import Foundation

/// Pure default-on alarm policy. Stored state records only explicit choices: exclusions win,
/// an explicit occurrence arm can override a series exclusion, and everything else is armed.
enum DefaultArming {
    static func isArmed(
        meeting: Meeting,
        explicitlyArmedIds: Set<String>,
        excludedMeetingIds: Set<String>,
        excludedSeriesIds: Set<String>,
        seriesExceptions: [String: Set<String>]
    ) -> Bool {
        guard !excludedMeetingIds.contains(meeting.id) else { return false }
        if explicitlyArmedIds.contains(meeting.id) {
            return true
        }
        guard let seriesId = meeting.seriesId else { return true }
        return !excludedSeriesIds.contains(seriesId)
            && !(seriesExceptions[seriesId]?.contains(meeting.id) ?? false)
    }
}
