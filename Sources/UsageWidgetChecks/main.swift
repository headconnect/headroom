// Minimal check runner: `swift run UsageWidgetChecks`. Exits non-zero on failure.
// `--live` additionally fetches usage for every signed-in provider and prints it.
import Foundation
@testable import UsageWidgetCore

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

check("countdown formatting") {
    let now = Date(timeIntervalSince1970: 0)
    return Format.countdown(to: now.addingTimeInterval(16_181), from: now) == "4h 30m"
        && Format.countdown(to: now.addingTimeInterval(537_385), from: now) == "6d 5h"
        && Format.countdown(to: now.addingTimeInterval(90), from: now) == "2m"
        && Format.countdown(to: now, from: now) == "now"
}

// MARK: Live (optional)

if CommandLine.arguments.contains("--live") {
    for provider in Provider.allCases {
        guard let tokens = TokenStore.load(provider) else {
            print("--   \(provider.name): not signed in")
            continue
        }
        do {
            let snapshot = try await provider.service.fetchUsage(tokens)
            let summary = snapshot.windows.map { window in
                let reset = window.resetsAt.map { " (resets in \(Format.countdown(to: $0, from: .now)))" } ?? ""
                return "\(window.label) \(Int(window.percentUsed.rounded()))%\(reset)"
            }
            print("ok   \(provider.name) [\(tokens.account ?? "?")]: \(summary.joined(separator: ", "))")
        } catch {
            print("FAIL \(provider.name): \(error.localizedDescription)")
            failures += 1
        }
    }
}

print(failures == 0 ? "All checks passed." : "\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
