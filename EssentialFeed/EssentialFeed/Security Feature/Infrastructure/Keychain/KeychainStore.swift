import Foundation

public enum KeychainOperationResult: Equatable {
    case success
    case failure(KeychainError)
}

public protocol KeychainStore {
    func get(_ key: String) -> String?

    @discardableResult
    func save(_ value: String, for key: String) -> KeychainOperationResult

    @discardableResult
    func delete(_ key: String) -> KeychainOperationResult
}
