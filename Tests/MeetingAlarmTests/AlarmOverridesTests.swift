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

    @Test("Silent and specific-sound overrides are distinct values")
    func soundOverrideCases() throws {
        #expect(SoundOverride.silent != SoundOverride.sound(.alarm))
        let silent = try JSONDecoder().decode(
            SoundOverride.self, from: JSONEncoder().encode(SoundOverride.silent)
        )
        #expect(silent == .silent)
    }
}
