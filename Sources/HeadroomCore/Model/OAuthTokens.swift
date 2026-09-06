import Foundation

struct OAuthTokens: Codable, Equatable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?
    /// Display label for the signed-in account (email, plan).
    var account: String?
    /// Codex only: ChatGPT account id, sent as a request header.
    var accountID: String?

    /// True when the access token expires within a few minutes.
    var needsRefresh: Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSinceNow < 5 * 60
    }
}
