import Foundation

/// Per-occurrence arming mutations, split from `Store` to keep each file under the size limit.
/// Stored state records only the user's explicit choices — custom arms and opt-out exclusions;
/// the default for untouched meetings is decided by the `autoArm` setting (opt-in when off).
extension Store {
    func arm(_ meeting: Meeting, preset: String) {
        armed[meeting.id] = ArmedConfig(presetName: preset, meeting: meeting)
        handled.remove(meeting.id)
        save()
    }

    func disarm(_ id: String) {
        armed[id] = nil
        handled.remove(id)
        armOverrides[id] = nil
        save()
    }

    /// Opt out of one occurrence. This is persisted so the next calendar refresh does not
    /// silently re-arm an event the user deliberately unchecked.
    func exclude(_ id: String) {
        excludedMeetingIds.insert(id)
        armed[id] = nil
        handled.remove(id)
        snoozes[id] = nil
        armOverrides[id] = nil
        save()
    }

    /// Re-enable one occurrence. Keeping an explicit snapshot lets it override a series-wide
    /// exclusion while also preserving the chosen preset across a relaunch.
    func include(_ meeting: Meeting, preset: String) {
        excludedMeetingIds.remove(meeting.id)
        armed[meeting.id] = ArmedConfig(presetName: preset, meeting: meeting)
        handled.remove(meeting.id)
        save()
    }

    /// Set (or clear, when `isEmpty`) the per-meeting color/sound override for an occurrence.
    func setOverrides(_ id: String, _ overrides: AlarmOverrides) {
        armOverrides[id] = overrides.isEmpty ? nil : overrides
        save()
    }

    /// Mark a fired+dismissed occurrence handled (stays armed for history, won't re-fire).
    func markHandled(_ id: String) {
        handled.insert(id)
        save()
    }

    /// Refresh an armed occurrence's snapshot (e.g. its time was edited) so the alarm
    /// re-times; a moved event also un-handles so it can fire again.
    func updateArmed(_ meeting: Meeting) {
        guard let config = armed[meeting.id] else { return }
        armed[meeting.id] = ArmedConfig(presetName: config.presetName, meeting: meeting)
        handled.remove(meeting.id)
        save()
    }
}
