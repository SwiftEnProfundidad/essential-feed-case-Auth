import Foundation
import Security

public protocol KeychainReadable {
    func getData(_ key: String) -> Data?
}

public protocol KeychainWritable {
    @discardableResult
    func save(_ data: Data, for key: String) -> KeychainOperationResult
}

public protocol KeychainRemovable {
    @discardableResult
    func delete(_ key: String) -> KeychainOperationResult
}

public extension KeychainReadable {
    func getString(_ key: String) -> String? {
        getData(key).flatMap { String(data: $0, encoding: .utf8) }
    }
}

public extension KeychainWritable {
    @discardableResult
    func save(_ string: String, for key: String) -> KeychainOperationResult {
        guard let data = string.data(using: .utf8) else {
            return .failure(.stringToDataConversionFailed)
        }
        let result = save(data, for: key)
        if case let .failure(error) = result, error == .stringToDataConversionFailed {
            return .failure(.stringToDataConversionFailed)
        }
        return result
    }
}

public final class KeychainHelper: KeychainReadable, KeychainWritable, KeychainRemovable {
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
