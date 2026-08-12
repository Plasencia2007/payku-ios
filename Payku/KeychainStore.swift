import Foundation
import Security

struct DeviceSession: Codable, Sendable, Equatable {
    let token: String
    let linkedAt: Date
}

enum KeychainStoreError: Error {
    case encodingFailed
    case decodingFailed
    case unavailable(OSStatus)
}

/// Stores only the device credential. It is never written to UserDefaults or logs.
final class KeychainStore: @unchecked Sendable {
    private let service: String
    private let account: String

    init(service: String = "com.tunegocio.payku.session", account: String = AppConfig.sessionKey) {
        self.service = service
        self.account = account
    }

    func readSession() throws -> DeviceSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainStoreError.unavailable(status) }
        guard let data = result as? Data else { throw KeychainStoreError.decodingFailed }
        do {
            return try JSONDecoder().decode(DeviceSession.self, from: data)
        } catch {
            throw KeychainStoreError.decodingFailed
        }
    }

    func save(_ session: DeviceSession) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(session)
        } catch {
            throw KeychainStoreError.encodingFailed
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let values: [String: Any] = [kSecValueData as String: data]
        let updateStatus: OSStatus = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery: [String: Any] = query
            addQuery[kSecValueData as String] = data
            let addStatus: OSStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainStoreError.unavailable(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw KeychainStoreError.unavailable(updateStatus)
        }
    }

    func deleteSession() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status: OSStatus = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unavailable(status)
        }
    }
}

