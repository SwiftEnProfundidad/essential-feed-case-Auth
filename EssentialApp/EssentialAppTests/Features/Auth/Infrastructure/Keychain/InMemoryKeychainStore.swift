import EssentialApp
import Foundation

final class InMemoryKeychainStore: KeychainStore {
    private var store = [String: String]()
    private let queue = DispatchQueue(label: "InMemoryKeychainStore.Queue")

    func set(_ value: String, for key: String) {
        queue.async(flags: .barrier) {
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
        queue.async(flags: .barrier) {
            self.store.removeValue(forKey: key)
        }
    }
}
