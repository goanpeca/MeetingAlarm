import Foundation
@testable import MeetingAlarm
import Testing

@Suite("SecretStore")
struct SecretStoreTests {
    @Test("set/get round-trips and delete via nil")
    func roundTrip() {
        let store: SecretStore = InMemorySecretStore()
        store.setString("token", for: "refresh:acc-1")
        #expect(store.getString("refresh:acc-1") == "token")
        store.set(nil, for: "refresh:acc-1")
        #expect(store.get("refresh:acc-1") == nil)
    }
}
