import AppKit
import Foundation

enum GoogleAuthError: LocalizedError {
    case notConfigured
    case tokenExchangeFailed(String)
    case noRefreshToken
    case userInfoFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Enter your Google OAuth client id and secret in Accounts first."
        case let .tokenExchangeFailed(detail):
            "Google sign-in failed: \(detail)"
        case .noRefreshToken:
            "This account needs to be reconnected."
        case .userInfoFailed:
            "Could not read the Google account email."
        }
    }
}

/// OAuth 2.0 (PKCE loopback) for one or more Google accounts. Refresh tokens live in the
/// Keychain keyed by account id; access tokens are cached in memory per account.
@MainActor
final class GoogleAuth {
    static let clientIdKey = "google.clientId"
    static let clientSecretKey = "google.clientSecret"

    private let scopes = [
        "https://www.googleapis.com/auth/calendar.events.readonly",
        "openid",
        "email"
    ]
    private let secrets: SecretStore
    private let accounts: GoogleAccountStore
    private var accessTokens: [String: (token: String, expiry: Date)] = [:]
    private let log = Log.make("google-auth")

    init(secrets: SecretStore, accounts: GoogleAccountStore) {
        self.secrets = secrets
        self.accounts = accounts
    }

    var clientId: String {
        secrets.getString(Self.clientIdKey) ?? ""
    }

    var isConfigured: Bool {
        !clientId.isEmpty && !(secrets.getString(Self.clientSecretKey) ?? "").isEmpty
    }

    func setCredentials(clientId: String, clientSecret: String) {
        secrets.setString(clientId, for: Self.clientIdKey)
        secrets.setString(clientSecret, for: Self.clientSecretKey)
    }

    func addAccount() async throws -> GoogleAccount {
        guard let clientId = secrets.getString(Self.clientIdKey), !clientId.isEmpty,
              let clientSecret = secrets.getString(Self.clientSecretKey), !clientSecret.isEmpty
        else { throw GoogleAuthError.notConfigured }

        let server = LoopbackServer()
        let port = try await server.start()
        defer { server.stop() }
        let redirectURI = "http://127.0.0.1:\(port)"
        let verifier = Self.randomVerifier()
        let pkce = GoogleOAuth.makePKCE(verifier: verifier)
        let state = UUID().uuidString
        let url = GoogleOAuth.authURL(
            clientId: clientId, redirectURI: redirectURI,
            scopes: scopes, challenge: pkce.challenge, state: state
        )
        NSWorkspace.shared.open(url)

        let code = try await server.waitForCode(expectedState: state)
        let body = GoogleOAuth.tokenRequestBody(
            code: code, verifier: verifier, clientId: clientId,
            clientSecret: clientSecret, redirectURI: redirectURI
        )
        let token = try await postToken(body: body)
        guard let refresh = token.refreshToken else {
            throw GoogleAuthError.tokenExchangeFailed("no refresh token returned")
        }
        let info = try await fetchUserInfo(accessToken: token.accessToken)
        secrets.setString(refresh, for: "refresh:\(info.sub)")
        accessTokens[info.sub] = (
            token.accessToken,
            Date().addingTimeInterval(TimeInterval(token.expiresIn))
        )
        let account = GoogleAccount(id: info.sub, email: info.email)
        accounts.add(account)
        return account
    }

    func removeAccount(id: String) {
        secrets.set(nil, for: "refresh:\(id)")
        accessTokens[id] = nil
        accounts.remove(id: id)
    }

    func accessToken(for accountId: String) async throws -> String {
        if let cached = accessTokens[accountId], cached.expiry > Date().addingTimeInterval(60) {
            return cached.token
        }
        guard let clientId = secrets.getString(Self.clientIdKey),
              let clientSecret = secrets.getString(Self.clientSecretKey)
        else { throw GoogleAuthError.notConfigured }
        guard let refresh = secrets.getString("refresh:\(accountId)") else {
            throw GoogleAuthError.noRefreshToken
        }
        let body = GoogleOAuth.refreshRequestBody(
            refreshToken: refresh, clientId: clientId, clientSecret: clientSecret
        )
        let token = try await postToken(body: body)
        accessTokens[accountId] = (
            token.accessToken,
            Date().addingTimeInterval(TimeInterval(token.expiresIn))
        )
        return token.accessToken
    }

    // MARK: Networking

    private func postToken(body: String) async throws -> TokenResponse {
        guard let url = URL(string: GoogleOAuth.tokenEndpoint) else {
            throw GoogleAuthError.tokenExchangeFailed("bad token endpoint")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200 ..< 300).contains(http.statusCode) else {
            throw GoogleAuthError
                .tokenExchangeFailed(String(data: data, encoding: .utf8) ?? "unknown")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func fetchUserInfo(accessToken: String) async throws -> UserInfo {
        guard let url = URL(string: GoogleOAuth.userInfoEndpoint) else {
            throw GoogleAuthError.userInfoFailed
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200 ..< 300).contains(http.statusCode) else {
            throw GoogleAuthError.userInfoFailed
        }
        return try JSONDecoder().decode(UserInfo.self, from: data)
    }

    private static func randomVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        for index in bytes.indices {
            bytes[index] = UInt8.random(in: 0 ... 255)
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct UserInfo: Decodable {
    let sub: String
    let email: String
}
