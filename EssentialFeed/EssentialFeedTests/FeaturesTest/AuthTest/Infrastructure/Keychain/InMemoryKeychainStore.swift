import EssentialFeed
import Foundation

final class InMemoryKeychainStore: KeychainStore {
    private var store = [String: String]()
    private let queue = DispatchQueue(label: "InMemoryKeychainStore.Queue")

    func set(_ value: String, for key: String) {
        queue.sync {
            self.store[key] = value
        }
    }

    func get(_ key: String) -> String? {
        var result: String?
        queue.sync {
            result = self.store[key]
        }
        return result
    }

    func delete(_ key: String) {
        _ = queue.sync {
            self.store.removeValue(forKey: key)
        }
    }
}
