import Foundation

public enum KeychainOperationResult: Equatable {
    case success
    case failure(KeychainError)
}

public protocol KeychainStringStore {
    func get(_ key: String) -> String?
    @discardableResult
    func save(_ value: String, for key: String) -> KeychainOperationResult
    @discardableResult
    func delete(_ key: String) -> KeychainOperationResult
}

public protocol KeychainDataStore {
    func getData(_ key: String) -> Data?
    @discardableResult
    func save(_ value: Data, for key: String) -> KeychainOperationResult
    @discardableResult
    func deleteData(_ key: String) -> KeychainOperationResult
}

public protocol KeychainStore: KeychainStringStore, KeychainDataStore {}
