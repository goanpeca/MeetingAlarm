import Foundation

/// Small secret get/set/delete abstraction so callers (e.g. GoogleAuth) can be tested
/// with an in-memory fake — the real Keychain needs an entitled app bundle.
protocol SecretStore: Sendable {
    func set(_ value: Data?, for key: String)
    func get(_ key: String) -> Data?
}

extension SecretStore {
    func setString(_ value: String?, for key: String) {
        set(value.map { Data($0.utf8) }, for: key)
    }

    func getString(_ key: String) -> String? {
        get(key).flatMap { String(data: $0, encoding: .utf8) }
    }
}

/// Test/dev store. Lock-guarded so it is safe to share as `Sendable`.
final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    func set(_ value: Data?, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }

    func get(_ key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }
}
