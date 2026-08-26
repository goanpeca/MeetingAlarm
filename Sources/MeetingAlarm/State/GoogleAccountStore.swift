import Combine
import Foundation

/// The list of connected Google accounts (non-secret descriptors). Tokens themselves
/// live in the Keychain keyed by account id.
@MainActor
final class GoogleAccountStore: ObservableObject {
    @Published private(set) var accounts: [GoogleAccount] = []

    private let defaults: UserDefaults
    private let key = "google.accounts.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let list = try? JSONDecoder().decode([GoogleAccount].self, from: data) {
            accounts = list
        }
    }

    func add(_ account: GoogleAccount) {
        guard !accounts.contains(where: { $0.id == account.id }) else { return }
        accounts.append(account)
        save()
    }

    func remove(id: String) {
        accounts.removeAll { $0.id == id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, forKey: key)
        }
    }
}
