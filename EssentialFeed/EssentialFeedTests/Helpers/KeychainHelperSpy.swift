import EssentialFeed
import Foundation

public final class KeychainHelperSpy: KeychainStore {
    public var stubbedValue: String?

    public private(set) var getCalls: [String] = []
    public private(set) var saveCalls: [(String, String)] = []
    public private(set) var deleteCalls: [String] = []

    public init() {}

    public func get(_ key: String) -> String? {
        getCalls.append(key)
        return stubbedValue
    }

    @discardableResult
    public func save(_ value: String, for key: String) -> Bool {
        saveCalls.append((key, value))
        return true
    }

    @discardableResult
    public func delete(_ key: String) -> Bool {
        deleteCalls.append(key)
        return true
    }
}
