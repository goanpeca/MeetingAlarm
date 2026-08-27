import Foundation
@testable import MeetingAlarm
import Testing

@Suite("SensoryProfile presets")
struct SensoryProfileTests {
    @Test("Blast is an instant, high-intensity interrupt at meeting time")
    func blast() {
        let profile = SensoryProfile.blast
        #expect(profile.leadTime == 0)
        #expect(profile.effect == .flash)
        #expect(profile.peakOpacity > 0.7)
        #expect(profile.sound == .alarm)
    }

    @Test("Gentle Ramp starts early, eases in, and is calmer than Blast")
    func gentleRamp() {
        let profile = SensoryProfile.gentleRamp
        #expect(profile.leadTime >= 60)
        #expect(profile.effect == .ramp)
        #expect(profile.peakOpacity < SensoryProfile.blast.peakOpacity)
    }

    @Test("Every preset survives a Codable round-trip unchanged")
    func codableRoundTrip() throws {
        for profile in SensoryProfile.presets {
            let data = try JSONEncoder().encode(profile)
            let decoded = try JSONDecoder().decode(SensoryProfile.self, from: data)
            #expect(decoded == profile)
        }
    }

    @Test("Dismissal with an associated value round-trips through Codable")
    func dismissalCodable() throws {
        let dismissal = Dismissal.auto(after: 30)
        let data = try JSONEncoder().encode(dismissal)
        let decoded = try JSONDecoder().decode(Dismissal.self, from: data)
        #expect(decoded == dismissal)
    }

    @Test("Blast sits at full peak opacity the instant it fires")
    func blastOpacityIsInstant() {
        let profile = SensoryProfile.blast
        #expect(profile.overlayOpacity(atFraction: 0) == profile.peakOpacity)
        #expect(profile.overlayOpacity(atFraction: 1) == profile.peakOpacity)
    }

    @Test("Gentle Ramp eases from zero up to peak and clamps out-of-range input")
    func gentleRampOpacityCurve() {
        let profile = SensoryProfile.gentleRamp
        #expect(profile.overlayOpacity(atFraction: 0) == 0)
        #expect(abs(profile.overlayOpacity(atFraction: 1) - profile.peakOpacity) < 1e-9)
        // Quadratic easeIn sits below the linear midpoint halfway through.
        #expect(profile.overlayOpacity(atFraction: 0.5) < profile.peakOpacity * 0.5)
        // Out-of-range fractions clamp to the endpoints.
        #expect(profile.overlayOpacity(atFraction: -1) == 0)
        #expect(abs(profile.overlayOpacity(atFraction: 2) - profile.peakOpacity) < 1e-9)
    }

    @Test("Reduce Motion replaces easing with a linear rise (no acceleration)")
    func reduceMotionIsLinear() {
        let profile = SensoryProfile.gentleRamp
        let mid = profile.overlayOpacity(atFraction: 0.5, reduceMotion: true)
        #expect(abs(mid - profile.peakOpacity * 0.5) < 1e-9)
    }

    @Test("Jewel Drop is bundled and default; system sounds map to names")
    func soundChoiceMapping() {
        #expect(SoundChoice.allCases.first == .jewelDrop)
        #expect(SoundChoice.jewelDrop.resourceName == "jewel-drop")
        #expect(SoundChoice.jewelDrop.systemSoundName == nil)
        #expect(SoundChoice.chime.resourceName == nil)
        #expect(SoundChoice.chime.systemSoundName == "Glass")
    }
}
