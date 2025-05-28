import EssentialFeed
import Foundation

public final class KeychainHelperSpy: KeychainStore {
    public var stubbedValue: String?
    public var stubbedSaveError: KeychainError?
    public var stubbedDeleteError: KeychainError?

    public private(set) var getCalls: [String] = []
    public private(set) var saveCalls: [(String, String)] = []
    public private(set) var deleteCalls: [String] = []

    public init() {}

    public func get(_ key: String) -> String? {
        getCalls.append(key)
        return stubbedValue
    }

    @discardableResult
    public func save(_ value: String, for key: String) -> KeychainOperationResult {
        saveCalls.append((key, value))
        if let error = stubbedSaveError {
            return .failure(error)
        }
        return .success
    }

    @discardableResult
    public func delete(_ key: String) -> KeychainOperationResult {
        deleteCalls.append(key)
        if let error = stubbedDeleteError {
            return .failure(error)
        }
        return .success
    }
}
