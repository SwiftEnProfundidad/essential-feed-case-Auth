import EssentialFeed
import Foundation

final class InMemoryKeychainStore: KeychainStore {
    private var stringStore = [String: String]()
    private var dataStore = [String: Data]()
    private let queue = DispatchQueue(label: "InMemoryKeychainStore.Queue")

    // MARK: - String methods

    func get(_ key: String) -> String? {
        var result: String?
        queue.sync {
            result = self.stringStore[key]
        }
        return result
    }

    @discardableResult
    func save(_ value: String, for key: String) -> KeychainOperationResult {
        queue.sync {
            self.stringStore[key] = value
        }
        return .success(())
    }

    @discardableResult
    func delete(_ key: String) -> KeychainOperationResult {
        var existed = false
        queue.sync {
            if self.stringStore.removeValue(forKey: key) != nil {
                existed = true
            }
        }
        return existed ? .success(()) : .failure(.itemNotFound)
    }

    // MARK: - Data methods

    func getData(_ key: String) -> Data? {
        var result: Data?
        queue.sync {
            result = self.dataStore[key]
        }
        return result
    }

    @discardableResult
    func save(_ value: Data, for key: String) -> KeychainOperationResult {
        queue.sync {
            self.dataStore[key] = value
        }
        return .success(())
    }

    @discardableResult
    func deleteData(_ key: String) -> KeychainOperationResult {
        var existed = false
        queue.sync {
            if self.dataStore.removeValue(forKey: key) != nil {
                existed = true
            }
        }
        return existed ? .success(()) : .failure(.itemNotFound)
    }
}
