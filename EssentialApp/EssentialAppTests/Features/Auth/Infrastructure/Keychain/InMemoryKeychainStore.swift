import EssentialApp
import EssentialFeed
import Foundation

final class InMemoryKeychainStore: KeychainStore {
    private var store = [String: String]()
    private let queue = DispatchQueue(label: "InMemoryKeychainStore.Queue")

    func save(_ value: String, for key: String) -> Bool {
        queue.sync {
            self.store[key] = value
        }
        return true
    }

    func get(_ key: String) -> String? {
        var result: String?
        queue.sync {
            result = self.store[key]
        }
        return result
    }

    func delete(_ key: String) -> Bool {
        var existed = false
        queue.sync {
            if self.store.removeValue(forKey: key) != nil {
                existed = true
            }
        }
        return existed
    }
}
