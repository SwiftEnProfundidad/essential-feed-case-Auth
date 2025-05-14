import Foundation

import Security

public final class SystemKeychain: KeychainFull {
    private let keychain: KeychainFull?
    private let queue = DispatchQueue(label: "SystemKeychain.SerialQueue")
    private static let queueKey = DispatchSpecificKey<Void>()

    public func load(forKey key: String) -> Data? {
        if DispatchQueue.getSpecific(key: SystemKeychain.queueKey) != nil {
            _load(forKey: key)
        } else {
            queue.sync { _load(forKey: key) }
        }
    }

    private func _load(forKey key: String) -> Data? {
        if let keychain {
            return keychain.load(forKey: key)
        }
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }

    public init(keychain: KeychainFull? = nil) {
        self.keychain = keychain
        queue.setSpecific(key: SystemKeychain.queueKey, value: ())
    }

    public func delete(forKey key: String) -> Bool {
        if let keychain {
            return keychain.delete(forKey: key)
        }
        if DispatchQueue.getSpecific(key: SystemKeychain.queueKey) != nil {
            return _delete(forKey: key)
        } else {
            return queue.sync { _delete(forKey: key) }
        }
    }

    private func _delete(forKey key: String) -> Bool {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    public func save(data: Data, forKey key: String) -> KeychainSaveResult {
        if DispatchQueue.getSpecific(key: SystemKeychain.queueKey) != nil {
            _save(data: data, forKey: key)
        } else {
            queue.sync { _save(data: data, forKey: key) }
        }
    }

    private func _save(data: Data, forKey key: String) -> KeychainSaveResult {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !data.isEmpty else { return .failure }
        if let keychain {
            _ = keychain.delete(forKey: key)
            return saveWithKeychain(keychain, data: data, key: key)
        }
        return saveDirectly(data: data, key: key)
    }

    private func saveWithKeychain(_ keychain: KeychainFull, data: Data, key: String) -> KeychainSaveResult {
        switch keychain.save(data: data, forKey: key) {
        case .success:
            return .success
        case .duplicateItem:
            let updateStatus = keychain.update(data: data, forKey: key)
            return updateStatus == errSecSuccess ? .success : .duplicateItem
        case .failure:
            return .failure
        }
    }

    private func saveDirectly(data: Data, key: String) -> KeychainSaveResult {
        let maxAttempts = 5
        let delay: useconds_t = 20000
        var attempts = 0
        while attempts < maxAttempts {
            let query = makeQuery(forKey: key)
            SecItemDelete(query as CFDictionary)
            let queryWithData = makeQueryWithData(forKey: key, data: data)
            let status = SecItemAdd(queryWithData as CFDictionary, nil)
            if status == errSecSuccess {
                guard isDataPersisted(forKey: key, data: data) else {
                    waitAndRetry(&attempts, delay)
                    continue
                }
                return .success
            }
            if status == errSecDuplicateItem {
                return handleDuplicateItem(query: query, data: data, key: key, delay: delay, attempts: &attempts)
            }
            waitAndRetry(&attempts, delay)
        }
        return .failure
    }

    private func makeQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
    }

    private func makeQueryWithData(forKey key: String, data: Data) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
    }

    private func isDataPersisted(forKey key: String, data: Data) -> Bool {
        load(forKey: key) == data
    }

    private func waitAndRetry(_ attempts: inout Int, _ delay: useconds_t) {
        usleep(delay)
        attempts += 1
    }

    public func update(data: Data, forKey key: String) -> OSStatus {
        if DispatchQueue.getSpecific(key: SystemKeychain.queueKey) != nil {
            _update(data: data, forKey: key)
        } else {
            queue.sync { _update(data: data, forKey: key) }
        }
    }

    private func _update(data: Data, forKey key: String) -> OSStatus {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !data.isEmpty else { return errSecParam }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data
        ]
        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        return status
    }

    // MARK: - Private helpers

    public func handleDuplicateItem(query: [String: Any], data: Data, key: String, delay: useconds_t, attempts: inout Int) -> KeychainSaveResult {
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        guard updateStatus == errSecSuccess else {
            return .duplicateItem
        }
        guard let loaded = self.load(forKey: key), loaded == data else {
            usleep(delay)
            attempts += 1
            return .duplicateItem
        }
        return .success
    }
}

// MARK: - NoFallback

public final class NoFallback: KeychainSavable {
    public init() {}
    public func save(data _: Data, forKey _: String) -> KeychainSaveResult {
        .failure
    }

    public func load(forKey _: String) -> Data? {
        nil
    }
}
