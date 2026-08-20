import Foundation
import Security
import OSLog

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "KeychainHelper")

/// Helper for storing sensitive tokens (Notion integration tokens, OAuth secrets)
/// in the macOS Keychain with hardware-backed encryption.
public final class KeychainHelper: Sendable {
    public static let shared = KeychainHelper()
    
    private let serviceName = "com.aleksei.scribe.tokens"
    
    private init() {}
    
    // MARK: - Generic Keychain Access
    
    @discardableResult
    public func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Delete existing item if any
        delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Failed to save key '\(key)' to Keychain: \(status)")
            return false
        }
        return true
    }
    
    public func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data, let string = String(data: data, encoding: .utf8) {
            return string
        }
        return nil
    }
    
    @discardableResult
    public func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Notion Token Migration & Storage
    
    public static let notionTokenKey = "notion_integration_token"
    
    public func getNotionToken() -> String {
        if let token = read(key: Self.notionTokenKey), !token.isEmpty {
            return token
        }
        
        // Fallback & migrate from UserDefaults if present
        if let legacy = UserDefaults.standard.string(forKey: "notionIntegrationToken"), !legacy.isEmpty {
            save(key: Self.notionTokenKey, value: legacy)
            UserDefaults.standard.removeObject(forKey: "notionIntegrationToken")
            logger.info("Migrated legacy Notion token from UserDefaults to Secure Keychain")
            return legacy
        }
        
        return ""
    }
    
    public func setNotionToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            delete(key: Self.notionTokenKey)
        } else {
            save(key: Self.notionTokenKey, value: trimmed)
        }
        // Ensure legacy plaintext is removed
        UserDefaults.standard.removeObject(forKey: "notionIntegrationToken")
    }
}
