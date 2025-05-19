import Foundation

public protocol SecureStoreWriter {
    func save(_ data: Data, forKey key: String) throws
}

public protocol SecureStoreReader {
    func retrieve(forKey key: String) throws -> Data
}

public protocol SecureStoreDeleter {
    func delete(forKey key: String) throws
}

public protocol EncryptionService {
    func encrypt(_ data: Data) throws -> Data
    func decrypt(_ data: Data) throws -> Data
}

public typealias SecureStore = SecureStoreDeleter & SecureStoreReader & SecureStoreWriter
