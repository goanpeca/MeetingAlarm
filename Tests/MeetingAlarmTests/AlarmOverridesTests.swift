import Foundation
@testable import MeetingAlarm
import Testing

@Suite("AlarmOverrides")
struct AlarmOverridesTests {
    @Test("An unset override is empty; setting either field makes it non-empty")
    func isEmpty() {
        #expect(AlarmOverrides().isEmpty)
        #expect(!AlarmOverrides(color: .calmTeal).isEmpty)
        #expect(!AlarmOverrides(sound: .silent).isEmpty)
        #expect(!AlarmOverrides(color: .red, sound: .sound(.chime)).isEmpty)
    }

    @Test("Color + sound overrides round-trip through Codable")
    func codableRoundTrip() throws {
        let overrides = AlarmOverrides(color: .calmTeal, sound: .sound(.ping))
        let data = try JSONEncoder().encode(overrides)
        #expect(try JSONDecoder().decode(AlarmOverrides.self, from: data) == overrides)
    }

    @Test("layered: each set field wins, unset fields fall through to the base")
    func layered() {
        let series = AlarmOverrides(color: .red, sound: .sound(.chime))
        // An occurrence that only overrides the sound keeps the series color.
        let occurrence = AlarmOverrides(sound: .silent)
        #expect(occurrence.layered(over: series) == AlarmOverrides(color: .red, sound: .silent))
        // An empty occurrence inherits the whole series override.
        #expect(AlarmOverrides().layered(over: series) == series)
        // A fully-set occurrence ignores the base entirely.
        let full = AlarmOverrides(color: .calmTeal, sound: .sound(.ping))
        #expect(full.layered(over: series) == full)
    }

    @Test("Silent and specific-sound overrides are distinct values")
    func soundOverrideCases() throws {
        #expect(SoundOverride.silent != SoundOverride.sound(.alarm))
        let silent = try JSONDecoder().decode(
            SoundOverride.self, from: JSONEncoder().encode(SoundOverride.silent)
        )
        #expect(silent == .silent)
    }
}
