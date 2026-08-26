import Foundation
import Security

/// `SecretStore` backed by the login Keychain (generic password items). Used for the
/// OAuth client secret and each account's refresh token (keyed by account id).
final class KeychainSecretStore: SecretStore, @unchecked Sendable {
    private let service: String

    init(service: String = "com.goanpeca.MeetingAlarm") {
        self.service = service
    }

    func set(_ value: Data?, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        guard let value else { return }
        var add = query
        add[kSecValueData as String] = value
        SecItemAdd(add as CFDictionary, nil)
    }

    func get(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess else {
            return nil
        }
        return out as? Data
    }
}
