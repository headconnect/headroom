import Foundation

/// One-time move from one keychain item per provider to the single vault.
enum LegacyMigration {
    typealias Legacy = (provider: Provider, tokens: OAuthTokens)

    /// The pure half: each legacy item becomes an account with the provider's
    /// default tag, in provider order.
    static func fold(_ legacy: [Legacy]) -> (accounts: [Account], vault: [UUID: OAuthTokens]) {
        var accounts: [Account] = []
        var vault: [UUID: OAuthTokens] = [:]
        for entry in legacy {
            let account = Account(provider: entry.provider, tag: Account.defaultTag(for: entry.provider, existing: accounts))
            accounts.append(account)
            vault[account.id] = entry.tokens
        }
        return (accounts, vault)
    }

    /// Reads the old items and deletes them only once the vault holds their
    /// tokens; nil means a read or the vault write failed, so the caller must
    /// not record the migration as done and lose the untouched old items.
    static func run() -> (accounts: [Account], vault: [UUID: OAuthTokens])? {
        var legacy: [Legacy] = []
        do {
            for provider in Provider.allCases {
                if let tokens = try TokenStore.loadLegacy(provider) { legacy.append((provider, tokens)) }
            }
        } catch { return nil }
        let migrated = fold(legacy)
        guard !legacy.isEmpty else { return migrated }
        do { try TokenStore.save(migrated.vault) } catch { return nil }
        for entry in legacy { TokenStore.deleteLegacy(entry.provider) }
        return migrated
    }
}
