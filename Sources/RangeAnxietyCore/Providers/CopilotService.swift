import Foundation

/// GitHub Copilot usage via GitHub's OAuth device flow, as used by the Copilot
/// editor extensions. The user types a short code into github.com while we poll.
struct CopilotService: UsageService {
    let provider = Provider.copilot

    private static let clientID = "Iv1.b507a08c87ecfe98"
    private static let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
    private static let tokenURL = URL(string: "https://github.com/login/oauth/access_token")!
    private static let usageURL = URL(string: "https://api.github.com/copilot_internal/user")!

    func beginSignIn() async throws -> PendingSignIn {
        let data = try await HTTP.postJSON(Self.deviceCodeURL, body: ["client_id": Self.clientID, "scope": "read:user"])
        let device = try JSONDecoder.api.decode(DeviceCode.self, from: data)
        guard let url = URL(string: device.verificationUri) else { throw ServiceError.malformedResponse }
        return PendingSignIn(url: url, mode: .deviceCode(device.userCode), finish: { _ in
            var tokens = try await poll(device)
            tokens.account = try? await accountLabel(tokens)
            return tokens
        }, cancel: {})
    }

    func refresh(_ tokens: OAuthTokens) async throws -> OAuthTokens {
        guard let refreshToken = tokens.refreshToken else { throw ServiceError.unauthorized }
        let data = try await HTTP.postJSON(Self.tokenURL, body: [
            "client_id": Self.clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
        ])
        let response = try JSONDecoder.api.decode(TokenResponse.self, from: data)
        guard let accessToken = response.accessToken else { throw ServiceError.unauthorized }
        return Self.tokens(from: response, accessToken: accessToken, previous: tokens)
    }

    func fetchUsage(_ tokens: OAuthTokens) async throws -> UsageSnapshot {
        let usage = try await usage(tokens)
        return UsageSnapshot(windows: usage.windows(), fetchedAt: .now)
    }

    /// Polls the token endpoint until the user has entered the code. Task
    /// cancellation stops the loop.
    private func poll(_ device: DeviceCode) async throws -> OAuthTokens {
        let deadline = Date(timeIntervalSinceNow: device.expiresIn)
        var interval = max(device.interval ?? 5, 5)
        while Date() < deadline {
            try await Task.sleep(for: .seconds(interval))
            let data = try await HTTP.postJSON(Self.tokenURL, body: [
                "client_id": Self.clientID,
                "device_code": device.deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            ])
            let response = try JSONDecoder.api.decode(TokenResponse.self, from: data)
            if let accessToken = response.accessToken {
                return Self.tokens(from: response, accessToken: accessToken, previous: nil)
            }
            switch response.error {
            case "authorization_pending": continue
            case "slow_down": interval += 5
            case let error?: throw ServiceError.signIn(response.errorDescription ?? error)
            case nil: throw ServiceError.malformedResponse
            }
        }
        throw ServiceError.signIn("the code expired before it was entered")
    }

    private func accountLabel(_ tokens: OAuthTokens) async throws -> String {
        let usage = try await usage(tokens)
        return [usage.login, usage.copilotPlan.map { "(\($0.capitalized))" }].compactMap { $0 }.joined(separator: " ")
    }

    private func usage(_ tokens: OAuthTokens) async throws -> CopilotUsage {
        let data = try await HTTP.get(Self.usageURL, headers: ["Authorization": "token \(tokens.accessToken)"])
        return try JSONDecoder.api.decode(CopilotUsage.self, from: data)
    }

    private static func tokens(from response: TokenResponse, accessToken: String, previous: OAuthTokens?) -> OAuthTokens {
        OAuthTokens(
            accessToken: accessToken,
            refreshToken: response.refreshToken ?? previous?.refreshToken,
            expiresAt: response.expiresIn.map { Date(timeIntervalSinceNow: $0) },
            account: previous?.account
        )
    }
}

private struct DeviceCode: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Double
    let interval: Double?
}

private struct TokenResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Double?
    let error: String?
    let errorDescription: String?
}

struct CopilotUsage: Decodable {
    struct Quota: Decodable {
        let percentRemaining: Double?
        let unlimited: Bool?
        let entitlement: Double?
        let remaining: Double?
        let overageCount: Double?
    }

    let login: String?
    let copilotPlan: String?
    let quotaResetDateUtc: Date?
    let quotaSnapshots: [String: Quota]?

    private static let labels: [String: String] = [
        "premium_interactions": "Premium requests (monthly)",
        "chat": "Chat",
        "completions": "Completions",
    ]
    private static let order = ["premium_interactions", "chat", "completions"]

    /// Metered quotas only; unlimited ones are not interesting.
    func windows() -> [UsageWindow] {
        (quotaSnapshots ?? [:])
            .filter { $0.value.unlimited != true && $0.value.percentRemaining != nil }
            .sorted { rank($0.key) < rank($1.key) }
            .map { key, quota in
                UsageWindow(id: key, label: Self.labels[key] ?? key.replacingOccurrences(of: "_", with: " ").capitalized,
                            percentUsed: 100 - (quota.percentRemaining ?? 0), resetsAt: quotaResetDateUtc, detail: Self.detail(quota))
            }
    }

    private static func detail(_ quota: Quota) -> String? {
        guard let entitlement = quota.entitlement, let remaining = quota.remaining, entitlement > 0 else { return nil }
        var text = "\(Int(remaining).formatted()) of \(Int(entitlement).formatted()) left"
        if let overage = quota.overageCount, overage > 0 { text += ", \(Int(overage).formatted()) overage" }
        return text
    }

    private func rank(_ key: String) -> (Int, String) {
        (Self.order.firstIndex(of: key) ?? Self.order.count, key)
    }
}
