import CryptoKit
import Foundation

/// PKCE verifier/challenge pair plus a CSRF state value (RFC 7636).
struct PKCE {
    let verifier: String
    let challenge: String
    let state: String

    init() {
        verifier = PKCE.randomToken()
        challenge = PKCE.challenge(for: verifier)
        state = PKCE.randomToken()
    }

    static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded()
    }

    private static func randomToken() -> String {
        Data((0..<32).map { _ in UInt8.random(in: .min ... .max) }).base64URLEncoded()
    }
}

extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
