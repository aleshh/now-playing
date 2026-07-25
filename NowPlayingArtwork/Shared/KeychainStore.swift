import Foundation
import Security

enum KeychainStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)"
        case .invalidData:
            return "The Keychain item contained invalid data."
        }
    }
}

enum KeychainStore {
    private static let service = "com.example.NowPlayingArtwork.credentials"

    static func set(_ data: Data, account: String) throws {
        var query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    static func data(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
        guard let data = result as? Data else {
            throw KeychainStoreError.invalidData
        }
        return data
    }

    static func remove(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    static func setString(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainStoreError.invalidData
        }
        try set(data, account: account)
    }

    static func string(account: String) throws -> String? {
        guard let data = try data(account: account) else {
            return nil
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw KeychainStoreError.invalidData
        }
        return value
    }

    static func setCodable<T: Encodable>(_ value: T, account: String) throws {
        try set(JSONEncoder().encode(value), account: account)
    }

    static func codable<T: Decodable>(_ type: T.Type, account: String) throws -> T? {
        guard let data = try data(account: account) else {
            return nil
        }
        return try JSONDecoder().decode(type, from: data)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let accessGroup = resolvedAccessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    private static let resolvedAccessGroup: String? = {
        let probeService = "\(service).access-group-probe"
        let probeAccount = UUID().uuidString
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: probeService,
            kSecAttrAccount as String: probeAccount,
            kSecValueData as String: Data([0]),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(addQuery as CFDictionary, nil)

        let readQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: probeService,
            kSecAttrAccount as String: probeAccount,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(readQuery as CFDictionary, &result)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: probeService,
            kSecAttrAccount as String: probeAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        guard status == errSecSuccess,
              let attributes = result as? [String: Any],
              let defaultGroup = attributes[kSecAttrAccessGroup as String] as? String,
              let separator = defaultGroup.firstIndex(of: ".")
        else {
            return nil
        }

        let prefix = defaultGroup[...separator]
        return String(prefix) + SharedConfiguration.keychainGroupSuffix
    }()
}

enum CredentialAccount {
    static let spotifyClientID = "spotify.client-id"
    static let spotifyToken = "spotify.oauth-token"
    static let sonosClientID = "sonos.client-id"
    static let sonosClientSecret = "sonos.client-secret"
    static let sonosToken = "sonos.oauth-token"
    static let sonosOAuthState = "sonos.oauth-state"
}

enum CredentialVault {
    static func string(_ account: String) -> String? {
        try? KeychainStore.string(account: account)
    }

    static func saveString(_ value: String, account: String) throws {
        try KeychainStore.setString(value, account: account)
    }

    static func token(_ account: String) -> OAuthToken? {
        try? KeychainStore.codable(OAuthToken.self, account: account)
    }

    static func saveToken(_ token: OAuthToken, account: String) throws {
        try KeychainStore.setCodable(token, account: account)
    }

    static func remove(_ account: String) {
        try? KeychainStore.remove(account: account)
    }
}
