import Foundation
@testable import MeetingAlarm
import Testing

@MainActor
@Suite("GoogleAccountStore")
struct GoogleAccountStoreTests {
    func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)") ?? .standard
    }

    @Test("add/remove persist and add is idempotent by id")
    func addRemove() {
        let defaults = makeDefaults()
        let store = GoogleAccountStore(defaults: defaults)
        store.add(GoogleAccount(id: "a1", email: "a@x.com"))
        store.add(GoogleAccount(id: "a1", email: "a@x.com")) // dup ignored
        store.add(GoogleAccount(id: "a2", email: "b@x.com"))
        #expect(store.accounts.count == 2)

        let reloaded = GoogleAccountStore(defaults: defaults)
        #expect(reloaded.accounts.map(\.id) == ["a1", "a2"])
        reloaded.remove(id: "a1")
        #expect(GoogleAccountStore(defaults: defaults).accounts.map(\.id) == ["a2"])
    }
}
