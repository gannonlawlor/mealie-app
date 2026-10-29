import Foundation
import Security

protocol CredentialVault {
    func read(_ key: String) throws -> String?
    func write(_ value: String?, for key: String) throws
}

struct KeychainCredentialVault: CredentialVault {
    // Both targets already have this App Group entitlement. App Groups also
    // grant access to keychain items explicitly assigned to the group.
    private let group = "group.com.jackabee.mealie"
    private let service = "com.jackabee.mealie.credentials"

    private func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key,
         kSecAttrAccessGroup as String: group]
    }

    func read(_ key: String) throws -> String? {
        var attributes = query(key)
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw VaultError.status(status) }
        guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw VaultError.invalidData
        }
        return value
    }

    func write(_ value: String?, for key: String) throws {
        let attributes = query(key)
        guard let value else {
            let status = SecItemDelete(attributes as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw VaultError.status(status)
            }
            return
        }
        let values: [String: Any] = [kSecValueData as String: Data(value.utf8),
                                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        var status = SecItemUpdate(attributes as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(attributes.merging(values) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw VaultError.status(status) }
    }

    enum VaultError: Error { case status(OSStatus), invalidData }
}

/// Never delete legacy data until the vault has accepted it. Failed migrations
/// remain retryable, and a locked/unavailable keychain never falls back to plaintext.
final class SecureCredentialStore {
    private let vault: CredentialVault
    private let legacy: [UserDefaults]

    init(vault: CredentialVault = KeychainCredentialVault(), legacy: [UserDefaults]) {
        self.vault = vault
        self.legacy = legacy
    }

    func read(_ key: String) throws -> String? {
        if legacy.contains(where: { $0.bool(forKey: "revoked_" + key) }) {
            try vault.write(nil, for: key)
            return nil
        }
        if let value = try vault.read(key) {
            legacy.forEach { $0.removeObject(forKey: key) }
            return value
        }
        guard let value = legacy.compactMap({ $0.string(forKey: key) }).first else { return nil }
        try vault.write(value, for: key)
        legacy.forEach { $0.removeObject(forKey: key) }
        return value
    }

    func write(_ value: String?, for key: String) throws {
        if value == nil {
            // Remember logout even when protected storage is temporarily locked.
            legacy.forEach { $0.set(true, forKey: "revoked_" + key); $0.removeObject(forKey: key) }
        }
        try vault.write(value, for: key)
        legacy.forEach {
            $0.removeObject(forKey: key)
            if value != nil { $0.removeObject(forKey: "revoked_" + key) }
        }
    }
}
