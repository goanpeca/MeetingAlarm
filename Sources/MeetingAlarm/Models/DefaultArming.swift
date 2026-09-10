import Foundation

/// Pure alarm-arming policy for both modes. Explicit user choices always win — a per-occurrence
/// opt-out, an explicit occurrence arm, or a whole-series arm. `autoArm` only decides the
/// default for meetings the user hasn't touched: on = opt-out (everything armed unless
/// excluded), off = opt-in (nothing armed unless explicitly chosen).
enum DefaultArming {
    static func isArmed(
        meeting: Meeting,
        autoArm: Bool,
        explicitlyArmedIds: Set<String>,
        armedSeriesIds: Set<String>,
        excludedMeetingIds: Set<String>,
        excludedSeriesIds: Set<String>,
        seriesExceptions: [String: Set<String>]
    ) -> Bool {
        guard !excludedMeetingIds.contains(meeting.id) else { return false }
        if explicitlyArmedIds.contains(meeting.id) {
            return true
        }
        guard let seriesId = meeting.seriesId else { return autoArm }
        let skipped = seriesExceptions[seriesId]?.contains(meeting.id) ?? false
        if armedSeriesIds.contains(seriesId) {
            return !skipped
        }
        guard autoArm else { return false }
        return !excludedSeriesIds.contains(seriesId) && !skipped
    }
}
