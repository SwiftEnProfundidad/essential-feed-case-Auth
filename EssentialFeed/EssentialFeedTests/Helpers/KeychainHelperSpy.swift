import EssentialFeed
import Foundation

public final class KeychainHelperSpy: KeychainStore {
    public var stubbedValue: String?
    public var stubbedSaveError: KeychainError?
    public var stubbedDeleteError: KeychainError?

    public var stubbedData: Data?
    public var stubbedDataSaveError: KeychainError?
    public var stubbedDataDeleteError: KeychainError?

    public private(set) var getCalls: [String] = []
    public private(set) var saveCalls: [(String, String)] = []
    public private(set) var deleteCalls: [String] = []
    public private(set) var getDataCalls: [String] = []
    public private(set) var saveDataCalls: [(String, Data)] = []
    public private(set) var deleteDataCalls: [String] = []

    public init() {}

    // MARK: - String

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

    // MARK: - Data

    public func getData(_ key: String) -> Data? {
        getDataCalls.append(key)
        return stubbedData
    }

    @discardableResult
    public func save(_ value: Data, for key: String) -> KeychainOperationResult {
        saveDataCalls.append((key, value))
        if let error = stubbedDataSaveError {
            return .failure(error)
        }
        return .success
    }

    @discardableResult
    public func deleteData(_ key: String) -> KeychainOperationResult {
        deleteDataCalls.append(key)
        if let error = stubbedDataDeleteError {
            return .failure(error)
        }
        return .success
    }
}
