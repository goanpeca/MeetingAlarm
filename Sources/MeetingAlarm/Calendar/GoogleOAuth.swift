import CryptoKit
import Foundation

/// Base64url without padding, per RFC 7636.
private func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

struct PKCE: Equatable {
    let verifier: String
    let challenge: String
}

/// Pure OAuth 2.0 (PKCE) helpers — URL and body construction, no networking.
enum GoogleOAuth {
    static let authHost = "accounts.google.com"
    static let authPath = "/o/oauth2/v2/auth"
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"
    static let userInfoEndpoint = "https://openidconnect.googleapis.com/v1/userinfo"

    static func makePKCE(verifier: String) -> PKCE {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return PKCE(verifier: verifier, challenge: base64URL(Data(digest)))
    }

    static func authURL(
        clientId: String,
        redirectURI: String,
        scopes: [String],
        challenge: String,
        state: String
    ) -> URL {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = authHost
        comps.path = authPath
        comps.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: scopes.joined(separator: " ")),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent")
        ]
        return comps.url ?? URL(fileURLWithPath: "/")
    }

    static func tokenRequestBody(
        code: String,
        verifier: String,
        clientId: String,
        clientSecret: String,
        redirectURI: String
    ) -> String {
        func enc(_ value: String) -> String {
            value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
        }
        return [
            "grant_type=authorization_code",
            "code=\(enc(code))",
            "code_verifier=\(enc(verifier))",
            "client_id=\(enc(clientId))",
            "client_secret=\(enc(clientSecret))",
            "redirect_uri=\(enc(redirectURI))"
        ].joined(separator: "&")
    }

    static func refreshRequestBody(
        refreshToken: String,
        clientId: String,
        clientSecret: String
    ) -> String {
        func enc(_ value: String) -> String {
            value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
        }
        return [
            "grant_type=refresh_token",
            "refresh_token=\(enc(refreshToken))",
            "client_id=\(enc(clientId))",
            "client_secret=\(enc(clientSecret))"
        ].joined(separator: "&")
    }
}
