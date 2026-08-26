import Foundation
@testable import MeetingAlarm
import Testing

@Suite("GoogleOAuth helpers")
struct GoogleOAuthTests {
    @Test("PKCE challenge is base64url(SHA256(verifier)), unpadded (RFC 7636 vector)")
    func pkce() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let pkce = GoogleOAuth.makePKCE(verifier: verifier)
        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        #expect(!pkce.challenge.contains("="))
    }

    @Test("authURL contains the required query items")
    func authURL() throws {
        let url = GoogleOAuth.authURL(
            clientId: "cid", redirectURI: "http://127.0.0.1:5555/cb",
            scopes: ["a", "b"], challenge: "CH", state: "ST"
        )
        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(
            uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name, $0.value) }
        )
        #expect(comps.host == "accounts.google.com")
        #expect(items["client_id"] == "cid")
        #expect(items["code_challenge"] == "CH")
        #expect(items["code_challenge_method"] == "S256")
        #expect(items["scope"] == "a b")
        #expect(items["state"] == "ST")
        #expect(items["response_type"] == "code")
    }

    @Test("token body carries code, verifier and grant type")
    func tokenBody() {
        let body = GoogleOAuth.tokenRequestBody(
            code: "C", verifier: "V", clientId: "cid", clientSecret: "sec",
            redirectURI: "http://127.0.0.1:5555/cb"
        )
        #expect(body.contains("grant_type=authorization_code"))
        #expect(body.contains("code=C"))
        #expect(body.contains("code_verifier=V"))
    }

    @Test("refresh body carries the refresh token and grant type")
    func refreshBody() {
        let body = GoogleOAuth.refreshRequestBody(
            refreshToken: "RT", clientId: "cid", clientSecret: "sec"
        )
        #expect(body.contains("grant_type=refresh_token"))
        #expect(body.contains("refresh_token=RT"))
        #expect(body.contains("client_id=cid"))
    }
}
