import Foundation
import Security

public final class KeychainHelper: KeychainStore {
    public init() {}

    private func mapError(from status: OSStatus) -> KeychainError {
        switch status {
        case errSecItemNotFound:
            .itemNotFound
        case errSecDuplicateItem:
            .duplicateItem
        case errSecInteractionNotAllowed:
            .interactionNotAllowed
        case errSecSuccess:
            .unhandledError(status: status)
        default:
            .unhandledError(status: status)
        }
    }

    public func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    @discardableResult
    public func save(_ value: String, for key: String) -> KeychainOperationResult {
        guard let data = value.data(using: .utf8) else {
            return .failure(.stringToDataConversionFailed)
        }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            return .failure(mapError(from: deleteStatus))
        }

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            return .failure(mapError(from: status))
        }

        guard let savedValue = get(key) else {
            _ = SecItemDelete(attributes as CFDictionary)
            return .failure(.dataToStringConversionFailed)
        }

        guard savedValue == value else {
            _ = SecItemDelete(attributes as CFDictionary)
            return .failure(.invalidItemFormat)
        }

        return .success
    }

    @discardableResult
    public func delete(_ key: String) -> KeychainOperationResult {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            return .failure(mapError(from: status))
        }

        return .success
    }
}
