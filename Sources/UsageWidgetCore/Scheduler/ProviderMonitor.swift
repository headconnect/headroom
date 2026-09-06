import AppKit
import Foundation
import Observation

/// Owns sign-in state, the latest snapshot and the polling loop for one provider.
@MainActor
@Observable
final class ProviderMonitor: Identifiable {
    enum Status: Equatable {
        case signedOut
        case signingIn
        case idle
        case refreshing
        case error(String)
    }

    let provider: Provider
    private(set) var tokens: OAuthTokens?
    private(set) var snapshot: UsageSnapshot?
    private(set) var status: Status = .signedOut
    private(set) var lastChecked: Date?
    private(set) var nextCheck: Date?
    private(set) var policy = RefreshPolicy()
    private(set) var pendingSignIn: PendingSignIn?

    private let service: any UsageService
    private var loop: Task<Void, Never>?
    private var signInTask: Task<Void, Never>?

    nonisolated var id: Provider { provider }
    var isSignedIn: Bool { tokens != nil }

    init(provider: Provider) {
        self.provider = provider
        service = provider.service
        tokens = TokenStore.load(provider)
        if tokens != nil {
            status = .idle
            startLoop()
        }
    }

    // MARK: Polling

    func refreshNow() {
        policy.reset()
        startLoop()
    }

    private func startLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while let self, !Task.isCancelled {
                await fetchOnce()
                guard !Task.isCancelled else { return }
                let delay = nextDelay()
                nextCheck = Date(timeIntervalSinceNow: delay)
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private func fetchOnce() async {
        guard var current = tokens else { return }
        status = .refreshing
        do {
            if current.needsRefresh { current = try await refreshTokens(current) }
            let fresh: UsageSnapshot
            do {
                fresh = try await service.fetchUsage(current)
            } catch ServiceError.unauthorized {
                current = try await refreshTokens(current)
                fresh = try await service.fetchUsage(current)
            }
            policy.record(changed: fresh.hasChanges(since: snapshot))
            snapshot = fresh
            lastChecked = .now
            status = .idle
        } catch {
            // A manual refresh cancels the in-flight fetch; the new loop reports instead.
            guard !Task.isCancelled else { return }
            switch error as? ServiceError {
            case .unauthorized: signOut()
            case .rateLimited: policy.backOff()
            default: policy.reset()
            }
            status = .error(error.localizedDescription)
        }
    }

    private func refreshTokens(_ current: OAuthTokens) async throws -> OAuthTokens {
        let fresh = try await service.refresh(current)
        try TokenStore.save(fresh, for: provider)
        tokens = fresh
        return fresh
    }

    /// Policy interval, shortened so a window reset is picked up promptly.
    private func nextDelay() -> TimeInterval {
        var delay = policy.interval
        if let reset = snapshot?.earliestReset, reset > .now {
            delay = min(delay, reset.timeIntervalSinceNow + 15)
        }
        return max(delay, 30)
    }

    // MARK: Sign-in

    func signIn() {
        guard pendingSignIn == nil, signInTask == nil else { return }
        runSignInStep { [self] in
            let pending = try await service.beginSignIn()
            pendingSignIn = pending
            status = .signingIn
            if case .deviceCode(let code) = pending.mode {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
            }
            NSWorkspace.shared.open(pending.url)
            if pending.mode != .pastedCode { try await finishSignIn(pending, pastedCode: nil) }
        }
    }

    func submitPastedCode(_ code: String) {
        guard let pending = pendingSignIn, signInTask == nil else { return }
        runSignInStep { [self] in try await finishSignIn(pending, pastedCode: code) }
    }

    func cancelSignIn() {
        signInTask?.cancel()
        signInTask = nil
        pendingSignIn?.cancel()
        pendingSignIn = nil
        status = .signedOut
    }

    private func runSignInStep(_ step: @escaping @MainActor () async throws -> Void) {
        signInTask = Task {
            do {
                try await step()
            } catch {
                guard !Task.isCancelled else { return }
                pendingSignIn = nil
                status = .error(error.localizedDescription)
            }
            if !Task.isCancelled { signInTask = nil }
        }
    }

    private func finishSignIn(_ pending: PendingSignIn, pastedCode: String?) async throws {
        let fresh = try await pending.finish(pastedCode)
        try TokenStore.save(fresh, for: provider)
        pendingSignIn = nil
        tokens = fresh
        snapshot = nil
        refreshNow()
    }

    func signOut() {
        loop?.cancel()
        loop = nil
        TokenStore.delete(provider)
        tokens = nil
        snapshot = nil
        lastChecked = nil
        nextCheck = nil
        status = .signedOut
    }
}
