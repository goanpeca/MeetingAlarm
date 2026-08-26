import Foundation

/// A connected Google account. Its tokens live in Keychain keyed by `id`; only this
/// non-secret descriptor is persisted in UserDefaults.
struct GoogleAccount: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let email: String
}
