import Foundation
import Observation

/// Owns the accounts, their monitors and the token vault. Every token write
/// goes through here on the main actor, so parallel refreshes cannot clobber
/// each other's slot in the single keychain item.
@MainActor
@Observable
final class AccountStore {
    private(set) var monitors: [AccountMonitor] = []
    private var vault: [UUID: OAuthTokens] = [:]
    /// False when the keychain read failed; writing then would replace the
    /// other accounts' tokens with an empty vault.
    private var vaultLoaded = true
    private let defaults: UserDefaults

    var accounts: [Account] { monitors.map(\.account) }

    /// Codex's callback server binds a fixed localhost port, so only one
    /// account may sign in at a time.
    var isSigningIn: Bool { monitors.contains { $0.isSigningIn } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var accounts: [Account] = []
        var migrating = false
        // The key being absent, and only that, means the migration is still due.
        if let data = defaults.data(forKey: Settings.accounts) {
            accounts = (try? JSONDecoder().decode([Account].self, from: data)) ?? []
            // Skip the keychain entirely when nothing is signed in.
            if !accounts.isEmpty {
                do { vault = try TokenStore.load() } catch { vaultLoaded = false }
            }
        } else if let migrated = LegacyMigration.run(into: defaults) {
            accounts = migrated.accounts
            vault = migrated.vault
            migrating = true
        }
        // Before persist(), which writes `accounts` — that is monitors.map.
        monitors = accounts.map { AccountMonitor(account: $0, store: self) }
        if migrating { persist() }
        pruneVault()
    }

    /// Tokens whose account is gone (a write that raced a removal, a hand-edited
    /// defaults file) would otherwise stay in the keychain forever.
    private func pruneVault() {
        let known = Set(monitors.map(\.id))
        guard vaultLoaded, vault.contains(where: { !known.contains($0.key) }) else { return }
        vault = vault.filter { known.contains($0.key) }
        try? TokenStore.save(vault)
    }

    @discardableResult
    func add(provider: Provider) -> Account {
        let account = Account(provider: provider, tag: Account.defaultTag(for: provider, existing: accounts))
        monitors.append(AccountMonitor(account: account, store: self))
        persist()
        return account
    }

    func remove(id: UUID) {
        guard let index = monitors.firstIndex(where: { $0.id == id }) else { return }
        monitors[index].stop()
        // Forget the secret while the id is still known to setTokens.
        if vault[id] != nil { try? setTokens(nil, for: id) }
        monitors.remove(at: index)
        persist()
    }

    /// Reorders the monitors, which is the persisted display order.
    func move(id: UUID, by offset: Int) {
        guard let index = monitors.firstIndex(where: { $0.id == id }) else { return }
        let order = Account.moved(accounts, at: index, by: offset).map(\.id)
        monitors.sort { order.firstIndex(of: $0.id)! < order.firstIndex(of: $1.id)! }
        persist()
    }

    /// Metadata edits (tag, name, menu bar override, icon); tokens are untouched.
    func update(_ account: Account) {
        guard let monitor = monitors.first(where: { $0.id == account.id }) else { return }
        var account = account
        account.tag = Account.normalized(tag: account.tag, provider: account.provider)
        monitor.account = account
        persist()
    }

    func tokens(for id: UUID) -> OAuthTokens? { vault[id] }

    /// Ignores unknown ids so a reply that lands after the account was removed
    /// cannot put its tokens back.
    func setTokens(_ tokens: OAuthTokens?, for id: UUID) throws {
        guard monitors.contains(where: { $0.id == id }) else { return }
        if !vaultLoaded {
            vault = try TokenStore.load()
            vaultLoaded = true
        }
        vault[id] = tokens
        try TokenStore.save(vault)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        defaults.set(data, forKey: Settings.accounts)
    }
}
