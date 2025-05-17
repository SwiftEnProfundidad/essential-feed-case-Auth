import EssentialFeed
import Foundation

public final class KeychainHelperSpy: KeychainStore {
    public private(set) var setCalls: [(String, String)] = []
    public private(set) var getCalls: [String] = []
    public private(set) var deleteCalls: [String] = []
    private var store: [String: String] = [:]

    public init() {}

    public func set(_ value: String, for key: String) {
        setCalls.append((value, key))
        store[key] = value
    }

    public func get(_ key: String) -> String? {
        getCalls.append(key)
        return store[key]
    }

    public func delete(_ key: String) {
        deleteCalls.append(key)
        store.removeValue(forKey: key)
    }
}
