import Foundation
@testable import MeetingAlarm
import Testing

@Suite("Models Codable")
struct ModelsCodableTests {
    @Test("ArmedConfig carries its meeting and round-trips")
    func armedConfig() throws {
        let meeting = Meeting(
            id: "m1", title: "Sync",
            start: Date(timeIntervalSince1970: 100),
            end: Date(timeIntervalSince1970: 700),
            sourceKind: .eventKit, accountLabel: nil
        )
        let config = ArmedConfig(presetName: "Gentle Ramp", meeting: meeting)
        let data = try JSONEncoder().encode(config)
        #expect(try JSONDecoder().decode(ArmedConfig.self, from: data) == config)
        #expect(config.meeting.id == "m1")
    }
}
