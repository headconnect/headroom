import Foundation
import Security

/// Persists tokens in the login keychain, one item per provider.
enum TokenStore {
    private static let service = "no.enso.UsageWidget"

    static func load(_ provider: Provider) -> OAuthTokens? {
        var query = baseQuery(provider)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(OAuthTokens.self, from: data)
    }

    static func save(_ tokens: OAuthTokens, for provider: Provider) throws {
        let data = try JSONEncoder().encode(tokens)
        let query = baseQuery(provider)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData] = data
            try check(SecItemAdd(add as CFDictionary, nil))
        } else {
            try check(status)
        }
    }

    static func delete(_ provider: Provider) {
        SecItemDelete(baseQuery(provider) as CFDictionary)
    }

    private static func baseQuery(_ provider: Provider) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: provider.rawValue]
    }

    private static func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            throw ServiceError.keychain(message)
        }
    }
}
