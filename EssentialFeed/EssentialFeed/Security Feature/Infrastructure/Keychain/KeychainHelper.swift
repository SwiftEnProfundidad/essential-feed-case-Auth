import Foundation
import os.log
import Security

public final class KeychainHelper: KeychainStore {
    public static let recommendedMaxDataSize = 128 * 1024

    private enum Constants {
        static let maxRetryCount = 3
        static let retryDelay: TimeInterval = 0.1
    }

    private let queue = DispatchQueue(
        label: "com.essentialdeveloper.keychain",
        qos: .userInitiated,
        attributes: .concurrent
    )

    private let logger: KeychainErrorLogger

    public init(logger: KeychainErrorLogger = OSLogger()) {
        self.logger = logger
    }

    public func getData(_ key: String) -> Data? {
        queue.sync { [weak self] in
            guard let self else { return nil }
            var query = self.baseQuery(for: key)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            guard status == errSecSuccess, let data = result as? Data else {
                return nil
            }

            return data
        }
    }

    @discardableResult
    public func save(_ data: Data, for key: String) -> KeychainOperationResult {
        if key.isEmpty {
            return .failure(.invalidKeyFormat)
        }

        return deleteExistingItem(for: key)
            .flatMap { _ in addNewItem(data, for: key) }
            .mapError { error -> KeychainError in
                logger.logError("Failed to save to Keychain", error: error)
                return error
            }
    }

    @discardableResult
    public func delete(_ key: String) -> KeychainOperationResult {
        queue.sync(flags: .barrier) { [weak self] in
            guard let self else { return .failure(.unhandledError(errSecInternalError)) }
            let query = self.baseQuery(for: key)
            let status = SecItemDelete(query as CFDictionary)

            if status == errSecSuccess || status == errSecItemNotFound {
                return .success(())
            } else {
                return .failure(self.mapError(from: status))
            }
        }
    }

    public func clear() -> KeychainOperationResult {
        queue.sync(flags: .barrier) { [weak self] in
            guard let self else { return .failure(.unhandledError(errSecInternalError)) }
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrSynchronizable as String: kCFBooleanFalse as Any
            ]

            let status = SecItemDelete(query as CFDictionary)
            if status == errSecSuccess || status == errSecItemNotFound {
                return .success(())
            } else {
                return .failure(self.mapError(from: status))
            }
        }
    }

    private func deleteExistingItem(for key: String) -> KeychainOperationResult {
        let deleteResult = delete(key)
        if case let .failure(error) = deleteResult, error != .itemNotFound {
            self.logger.logError("Failed to delete existing item from Keychain", error: error)
            return .failure(error)
        }
        return .success(())
    }

    private func addNewItem(_ data: Data, for key: String) -> KeychainOperationResult {
        var query = baseQuery(for: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        var status = errSecSuccess
        var retryCount = 0
        var lastError: KeychainError?

        repeat {
            status = SecItemAdd(query as CFDictionary, nil)
            guard status != errSecSuccess, retryCount < Constants.maxRetryCount else { break }

            lastError = self.mapError(from: status)
            Thread.sleep(forTimeInterval: Constants.retryDelay * Double(retryCount + 1))
            retryCount += 1
        } while status != errSecSuccess

        if status == errSecSuccess {
            return .success(())
        } else {
            return .failure(lastError ?? self.mapError(from: status))
        }
    }

    private func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanFalse!
        ]

        if let accessGroup = Bundle.main.bundleIdentifier {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }

    private func mapError(from status: OSStatus) -> KeychainError {
        switch status {
        case errSecItemNotFound:
            .itemNotFound
        case errSecDuplicateItem:
            .duplicateItem
        case errSecParam:
            .invalidItemFormat
        case errSecNotAvailable, errSecMemoryError:
            .dataConversionFailed
        case errSecInteractionNotAllowed:
            .interactionNotAllowed
        default:
            .unhandledError(status)
        }
    }
}
