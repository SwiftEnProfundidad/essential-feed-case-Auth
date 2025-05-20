import EssentialFeed
import Foundation

final class InMemoryKeychainStore: KeychainStore {
    private var store = [String: String]()
    private let queue = DispatchQueue(label: "InMemoryKeychainStore.Queue")

    // MARK: - KeychainStore

    func get(_ key: String) -> String? {
        queue.sync { store[key] }
    }

    @discardableResult
    func save(_ value: String, for key: String) -> Bool {
        queue.sync {
            store[key] = value
            return true
        }
    }

    @discardableResult
    func delete(_ key: String) -> Bool {
        queue.sync {
            store.removeValue(forKey: key) != nil
        }
    }
}
