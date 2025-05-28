import EssentialFeed
import Foundation

final class InMemoryKeychainStore: KeychainStore {
    private var store = [String: String]()
    private let queue = DispatchQueue(label: "InMemoryKeychainStore.Queue")

    func get(_ key: String) -> String? {
        queue.sync { store[key] }
    }

    @discardableResult
    func save(_ value: String, for key: String) -> KeychainOperationResult {
        queue.sync {
            store[key] = value
            return .success
        }
    }

    @discardableResult
    func delete(_ key: String) -> KeychainOperationResult {
        queue.sync {
            store.removeValue(forKey: key)
            return .success
        }
    }
}
