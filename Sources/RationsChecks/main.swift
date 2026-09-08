// Minimal check runner: `swift run RationsChecks`. Exits non-zero on failure.
// `--live` additionally fetches usage for every signed-in account and prints it.
import AppKit
import Foundation
@testable import RationsCore

var failures = 0

func check(_ label: String, _ body: () throws -> Bool) {
    do {
        if try body() {
            print("ok   \(label)")
            return
        }
        print("FAIL \(label)")
    } catch {
        print("FAIL \(label): \(error)")
    }
    failures += 1
}

// MARK: RefreshPolicy

check("policy starts at base") { RefreshPolicy().interval == 5 * 60 }

check("change boosts to 2 min") {
    var policy = RefreshPolicy()
    policy.record(changed: true)
    return policy.interval == 2 * 60
}

check("unchanged backs off 5 → 10 → 20 → 20") {
    var policy = RefreshPolicy()
    policy.record(changed: true)
    var intervals: [TimeInterval] = []
    for _ in 0..<4 {
        policy.record(changed: false)
        intervals.append(policy.interval)
    }
    return intervals == [300, 600, 1200, 1200]
}

check("reset returns to base") {
    var policy = RefreshPolicy()
    policy.backOff()
    policy.reset()
    return policy.interval == 5 * 60
}

// MARK: Parsing

check("claude usage windows") {
    let json = """
    {
      "five_hour": {"utilization": 1.0, "resets_at": "2026-09-06T11:30:00.144211+00:00", "limit_dollars": null},
      "seven_day": {"utilization": 2.0, "resets_at": "2026-09-12T17:00:00+00:00"},
      "seven_day_opus": null,
      "nimbus_quill": {"utilization": 0.0, "resets_at": null},
      "extra_usage": {"is_enabled": false, "utilization": 67.7},
      "limits": [{"kind": "session", "percent": 1}],
      "spend": {"percent": 68, "enabled": false},
      "member_dashboard_available": false
    }
    """
    let windows = try JSONDecoder.apiRawKeys.decode(ClaudeUsage.self, from: Data(json.utf8)).windows()
    let ids: [String] = windows.map(\.id)
    let percents: [Double] = windows.map(\.percentUsed)
    return ids == ["five_hour", "seven_day"] && percents == [1, 2]
        && windows[0].resetsAt?.timeIntervalSince1970 == 1_788_694_200
}

check("claude extra usage shown when enabled") {
    let json = #"{"five_hour": {"utilization": 5.0}, "extra_usage": {"is_enabled": true, "utilization": 40.0}}"#
    let windows = try JSONDecoder.apiRawKeys.decode(ClaudeUsage.self, from: Data(json.utf8)).windows()
    return windows.map(\.id) == ["five_hour", "extra_usage"]
}

check("codex usage windows") {
    let json = """
    {
      "plan_type": "team",
      "rate_limit": {
        "allowed": true,
        "primary_window": {"used_percent": 77, "limit_window_seconds": 18000, "reset_after_seconds": 16181, "reset_at": 1788692687},
        "secondary_window": {"used_percent": 43, "limit_window_seconds": 604800, "reset_at": 1789213891}
      }
    }
    """
    let windows = try JSONDecoder.api.decode(CodexUsage.self, from: Data(json.utf8)).windows()
    let labels: [String] = windows.map(\.label)
    let percents: [Double] = windows.map(\.percentUsed)
    return labels == ["Session (5h)", "Weekly"] && percents == [77, 43]
        && windows[1].resetsAt?.timeIntervalSince1970 == 1_789_213_891
}

check("copilot usage windows skip unlimited quotas") {
    let json = """
    {
      "login": "octocat", "copilot_plan": "business", "quota_reset_date_utc": "2026-10-01T00:00:00.000Z",
      "quota_snapshots": {
        "chat": {"percent_remaining": 100.0, "unlimited": true, "entitlement": 0, "remaining": 0},
        "premium_interactions": {"percent_remaining": 81.5, "unlimited": false, "entitlement": 10000, "remaining": 8151, "overage_count": 0}
      }
    }
    """
    let windows = try JSONDecoder.api.decode(CopilotUsage.self, from: Data(json.utf8)).windows()
    return windows.count == 1 && windows[0].id == "premium_interactions" && windows[0].percentUsed == 18.5
        && windows[0].detail == "\(8151.formatted()) of \(10000.formatted()) left"  // locale-dependent grouping
        && windows[0].resetsAt?.timeIntervalSince1970 == 1_790_812_800
}

check("codex without rate limit") {
    try JSONDecoder.api.decode(CodexUsage.self, from: Data(#"{"rate_limit": null}"#.utf8)).windows().isEmpty
}

check("change detection ignores sub-second jitter") {
    let a = UsageWindow(id: "w", label: "W", percentUsed: 10, resetsAt: Date(timeIntervalSince1970: 100.2))
    let b = UsageWindow(id: "w", label: "W", percentUsed: 10, resetsAt: Date(timeIntervalSince1970: 100.9))
    let first = UsageSnapshot(windows: [a], fetchedAt: .now)
    let second = UsageSnapshot(windows: [b], fetchedAt: .now)
    return !second.hasChanges(since: first) && first.hasChanges(since: nil)
}

check("moving an account clamps at the ends") {
    let accounts = [Account(provider: .claude, tag: "A"), Account(provider: .codex, tag: "O"), Account(provider: .copilot, tag: "G")]
    return Account.moved(accounts, at: 2, by: -1).map(\.tag) == ["A", "G", "O"]
        && Account.moved(accounts, at: 0, by: -1).map(\.tag) == ["A", "O", "G"]
        && Account.moved(accounts, at: 1, by: 5).map(\.tag) == ["A", "G", "O"]
        && Account.moved(accounts, at: 7, by: 1).map(\.tag) == ["A", "O", "G"]
}

check("account icon is scaled to menu bar height") {
    let image = NSImage(size: NSSize(width: 100, height: 50), flipped: false) { rect in
        NSColor.red.setFill(); rect.fill(); return true
    }
    guard let data = AccountIcon.png(image), let rep = NSBitmapImageRep(data: data) else { return false }
    return rep.pixelsHigh == 32 && rep.pixelsWide == 64 && data.count < 2_000
}

// MARK: Auth helpers

check("pkce challenge matches RFC 7636 vector") {
    PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
}

check("jwt claims") {
    let payload = Data(#"{"exp": 1700000000, "email": "a@b.c"}"#.utf8).base64URLEncoded()
    let token = "eyJhbGciOiJub25lIn0.\(payload).sig"
    return JWT.claims(token)?["email"] as? String == "a@b.c"
        && JWT.expiry(token)?.timeIntervalSince1970 == 1_700_000_000
}

// MARK: Formatting

check("version comparison") {
    UpdateChecker.isNewer("1.1", than: "1.0.0") && UpdateChecker.isNewer("1.0.1", than: "1.0")
        && !UpdateChecker.isNewer("1.0.0", than: "1.0") && !UpdateChecker.isNewer("0.9.9", than: "1.0")
}

check("countdown formatting") {
    let now = Date(timeIntervalSince1970: 0)
    return Format.countdown(to: now.addingTimeInterval(16_181), from: now) == "4h 30m"
        && Format.countdown(to: now.addingTimeInterval(537_385), from: now) == "6d 5h"
        && Format.countdown(to: now.addingTimeInterval(90), from: now) == "2m"
        && Format.countdown(to: now, from: now) == "now"
}

// MARK: Accounts

check("vault json is keyed by account id and round trips") {
    let id = UUID()
    let tokens = OAuthTokens(accessToken: "a", refreshToken: "r", expiresAt: Date(timeIntervalSince1970: 100),
                             account: "me@example.com", accountID: "acc")
    let data = try JSONEncoder().encode(TokenStore.Vault([id: tokens]))
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let decoded = try JSONDecoder().decode(TokenStore.Vault.self, from: data)
    return json?["version"] as? Int == 1
        && (json?["tokens"] as? [String: Any])?.keys.sorted() == [id.uuidString]
        && decoded.byAccount == [id: tokens]
}

check("vault drops entries that are not account ids") {
    let json = #"{"version": 1, "tokens": {"claude": {"accessToken": "a"}}}"#
    return try JSONDecoder().decode(TokenStore.Vault.self, from: Data(json.utf8)).byAccount.isEmpty
}

check("migration turns legacy items into tagged accounts") {
    let legacy: [LegacyMigration.Legacy] = [
        (provider: .claude, tokens: OAuthTokens(accessToken: "c", refreshToken: nil, expiresAt: nil, account: nil, accountID: nil)),
        (provider: .copilot, tokens: OAuthTokens(accessToken: "g", refreshToken: nil, expiresAt: nil, account: nil, accountID: nil)),
    ]
    let (accounts, vault) = LegacyMigration.fold(legacy)
    return accounts.map(\.provider) == [.claude, .copilot]
        && accounts.map(\.tag) == ["A", "G"]
        && vault[accounts[0].id]?.accessToken == "c"
        && vault[accounts[1].id]?.accessToken == "g"
        && LegacyMigration.fold([]).accounts.isEmpty
}

check("tag is trimmed, capped at three clusters and falls back") {
    Account.normalized(tag: "  hi  ", provider: .claude) == "hi"
        && Account.normalized(tag: "abcde", provider: .claude) == "abc"
        && Account.normalized(tag: "   ", provider: .codex) == "O"
        && Account.normalized(tag: "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}x", provider: .claude).count == 2
}

check("second account of a provider is numbered") {
    let first = Account(provider: .claude, tag: Account.defaultTag(for: .claude, existing: []))
    let second = Account(provider: .claude, tag: Account.defaultTag(for: .claude, existing: [first]))
    return first.tag == "A" && second.tag == "A2"
        && Account.defaultTag(for: .claude, existing: [second]) == "A"
        && Account.defaultTag(for: .codex, existing: [first, second]) == "O"
}

check("menu bar options follow the globals unless overridden") {
    let globals = MenuBarOptions(bars: false, percent: true, session: true, weekly: false)
    var account = Account(provider: .claude, tag: "A")
    let followed = MenuBarOptions.resolve(for: account, global: globals)
    account.menuBar = MenuBarOptions(bars: true, percent: false, session: false, weekly: true)
    return followed == globals && MenuBarOptions.resolve(for: account, global: globals) == account.menuBar
}

check("menu bar options keep one of each pair") {
    MenuBarOptions(bars: false, percent: false, session: false, weekly: false).paired == MenuBarOptions()
        && !MenuBarOptions(bars: false, percent: true, session: true, weekly: true).paired.bars
}

check("global menu bar options default to on") {
    let suite = "no.enso.rations.checks"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    let fresh = MenuBarOptions.global(defaults)
    defaults.set(false, forKey: Settings.menuBarWeekly)
    let edited = MenuBarOptions.global(defaults)
    defaults.removePersistentDomain(forName: suite)
    return fresh == MenuBarOptions() && !edited.weekly && edited.session
}

// MARK: Live (optional)

if CommandLine.arguments.contains("--live") {
    // Read-only on purpose: an AccountStore here would start polling loops that
    // refresh tokens and rewrite the vault behind the running app's back.
    let defaults = UserDefaults(suiteName: "no.enso.rations") ?? .standard
    let stored = defaults.data(forKey: Settings.accounts) ?? Data()
    let accounts = (try? JSONDecoder().decode([Account].self, from: stored)) ?? []
    let vault = accounts.isEmpty ? [:] : ((try? TokenStore.load()) ?? [:])
    for account in accounts {
        let label = "\(account.tag) \(account.provider.name)"
        guard let tokens = vault[account.id] else {
            print("--   \(label): not signed in")
            continue
        }
        do {
            let snapshot = try await account.provider.service.fetchUsage(tokens)
            let summary = snapshot.windows.map { window in
                let reset = window.resetsAt.map { " (resets in \(Format.countdown(to: $0, from: .now)))" } ?? ""
                return "\(window.label) \(Int(window.percentUsed.rounded()))%\(reset)"
            }
            print("ok   \(label) [\(tokens.account ?? "?")]: \(summary.joined(separator: ", "))")
        } catch {
            print("FAIL \(label): \(error.localizedDescription)")
            failures += 1
        }
    }
}

print(failures == 0 ? "All checks passed." : "\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
