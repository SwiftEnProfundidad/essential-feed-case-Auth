import Foundation

public enum KeychainOperationResult: Equatable {
    case success
    case failure(KeychainError)
}

// MARK: - Core Protocols

public protocol KeychainReadable {
    func getData(_ key: String) -> Data?
}

public protocol KeychainWritable {
    @discardableResult
    func save(_ data: Data, for key: String) -> KeychainOperationResult
}

public protocol KeychainRemovable {
    @discardableResult
    func delete(_ key: String) -> KeychainOperationResult
}

// MARK: - String Convenience

public extension KeychainReadable {
    func getString(_ key: String) -> String? {
        getData(key).flatMap { String(data: $0, encoding: .utf8) }
    }
}

public extension KeychainWritable {
    @discardableResult
    func save(_ string: String, for key: String) -> KeychainOperationResult {
        guard let data = string.data(using: .utf8) else {
            return .failure(.stringToDataConversionFailed)
        }
        return save(data, for: key)
    }
}

// MARK: - Typealiases for Composition

public typealias KeychainStringStore = KeychainReadable & KeychainRemovable & KeychainWritable
public typealias KeychainDataStore = KeychainReadable & KeychainRemovable & KeychainWritable
public typealias KeychainStore = KeychainReadable & KeychainRemovable & KeychainWritable
