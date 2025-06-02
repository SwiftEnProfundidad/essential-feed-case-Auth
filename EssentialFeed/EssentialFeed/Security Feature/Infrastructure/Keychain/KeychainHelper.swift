
import Foundation
import Security

public final class KeychainHelper: KeychainStore {
    private let queue = DispatchQueue(
        label: "com.essentialdeveloper.keychain", qos: .userInitiated, attributes: .concurrent
    )

    public init() {}

    public func getData(_ key: String) -> Data? {
        queue.sync {
            getData_nosync(key)
        }
    }

    @discardableResult
    public func save(_ data: Data, for key: String) -> KeychainOperationResult {
        queue.sync(flags: .barrier) {
            _ = delete_nosync(key)
            var query = baseQuery(for: key)
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemAdd(query as CFDictionary, nil)
            return (status == errSecSuccess) ? .success : .failure(mapError(from: status))
        }
    }

    @discardableResult
    public func delete(_ key: String) -> KeychainOperationResult {
        queue.sync(flags: .barrier) {
            delete_nosync(key)
        }
    }

    private func getData_nosync(_ key: String) -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status == errSecSuccess) ? (result as? Data) : nil
    }

    private func delete_nosync(_ key: String) -> KeychainOperationResult {
        let query = baseQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        return (status == errSecSuccess || status == errSecItemNotFound)
            ? .success : .failure(mapError(from: status))
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
    }

    private func mapError(from status: OSStatus) -> KeychainError {
        switch status {
        case errSecItemNotFound: .itemNotFound
        case errSecDuplicateItem: .duplicateItem
        case errSecInteractionNotAllowed: .interactionNotAllowed
        case errSecDecode: .decryptionFailed
        default: .unhandledError(status: status)
        }
    }
}
