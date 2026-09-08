import Foundation

/// One-time moves into the current stores, run when the accounts key is
/// absent from the defaults: the vault and settings written under one of the
/// app's previous names (Range Anxiety in 2.1, headroom up to 2.0), or the
/// 1.x keychain item per provider.
enum LegacyMigration {
    typealias Legacy = (provider: Provider, tokens: OAuthTokens)
    typealias Migrated = (accounts: [Account], vault: [UUID: OAuthTokens])

    /// The pure half: each legacy item becomes an account with the provider's
    /// default tag, in provider order.
    static func fold(_ legacy: [Legacy]) -> Migrated {
        var accounts: [Account] = []
        var vault: [UUID: OAuthTokens] = [:]
        for entry in legacy {
            let account = Account(provider: entry.provider, tag: Account.defaultTag(for: entry.provider, existing: accounts))
            accounts.append(account)
            vault[account.id] = entry.tokens
        }
        return (accounts, vault)
    }

    /// nil means a read or the vault write failed, so the caller must not
    /// record the migration as done and lose the untouched old items.
    static func run(into defaults: UserDefaults) -> Migrated? {
        // The newest previous name that has an account list wins; each rename
        // deleted the one before it, so normally only one exists.
        let domains = TokenStore.previousServices.map { ($0, UserDefaults.standard.persistentDomain(forName: $0) ?? [:]) }
        let (service, previous) = domains.first { $0.1[Settings.accounts] != nil }
            ?? (TokenStore.legacyService, UserDefaults.standard.persistentDomain(forName: TokenStore.legacyService) ?? [:])
        // Settings are copied first; doing it again on a retry is harmless.
        // The accounts key is what marks the migration done, so it is not.
        for (key, value) in previous where key != Settings.accounts { defaults.set(value, forKey: key) }
        guard let data = previous[Settings.accounts] as? Data else { return runLegacy() }
        return runPrevious(service: service, accounts: (try? JSONDecoder().decode([Account].self, from: data)) ?? [])
    }

    /// Moves a 2.x vault to this name and deletes the old item and defaults
    /// only once the new vault holds the tokens.
    private static func runPrevious(service: String, accounts: [Account]) -> Migrated? {
        let vault: [UUID: OAuthTokens]
        do { vault = try TokenStore.loadPrevious(service: service) ?? [:] } catch { return nil }
        if !vault.isEmpty {
            do { try TokenStore.save(vault) } catch { return nil }
        }
        TokenStore.deletePrevious(service: service)
        UserDefaults.standard.removePersistentDomain(forName: service)
        return (accounts, vault)
    }

    /// Reads the 1.x items and deletes them only once the vault holds their
    /// tokens.
    private static func runLegacy() -> Migrated? {
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
