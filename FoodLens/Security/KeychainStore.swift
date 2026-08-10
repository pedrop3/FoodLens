import Foundation
import Security


enum KeychainKey: String {
    case anthropicAPIKey = "com.foodlens.anthropicAPIKey"
    case usdaAPIKey = "com.foodlens.usdaAPIKey"
    case geminiAPIKey = "com.foodlens.geminiAPIKey"
    // Ollama corre localmente e não precisa de chave.
}

enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
    case unexpectedData
}


enum KeychainStore {
    static func set(_ value: String, for key: KeychainKey) throws {
        let data = Data(value.utf8)
        var query = baseQuery(for: key)


        if try get(key) != nil {
            let attributes: [String: Any] = [kSecValueData as String: data]
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
            return
        }

        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    
    static func get(_ key: KeychainKey) throws -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.unexpectedData
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func delete(_ key: KeychainKey) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private static func baseQuery(for key: KeychainKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
        ]
    }
}
