import Foundation
import Security

public final class KeychainManager: KeychainReader, KeychainWriter, KeychainEncryptor {
    private let reader: KeychainReader
    private let writer: KeychainWriter
    private let encryptor: KeychainEncryptor
    private let errorHandler: KeychainErrorHandler

    public init(reader: KeychainReader, writer: KeychainWriter, encryptor: KeychainEncryptor, errorHandler: KeychainErrorHandler) {
        self.reader = reader
        self.writer = writer
        self.encryptor = encryptor
        self.errorHandler = errorHandler
    }

    // MARK: - KeychainReader

    public func load(forKey key: String) throws -> Data? {
        do {
            return try reader.load(forKey: key)
        } catch let error as KeychainError {
            errorHandler.handle(error: error, forKey: key, operation: "load")
            throw error
        } catch {
            errorHandler.handle(error: .unhandledError(status: -1), forKey: key, operation: "load - unexpected error type")
            throw error
        }
    }

    // MARK: - KeychainWriter

    public func save(data: Data, forKey key: String) throws {
        do {
            let encryptedData = try encryptor.encrypt(data)
            try writer.save(data: encryptedData, forKey: key)
        } catch let error as KeychainError {
            errorHandler.handle(error: error, forKey: key, operation: "save")
            throw error
        } catch {
            errorHandler.handle(error: .unhandledError(status: -1), forKey: key, operation: "save - unexpected error type")
            throw error
        }
    }

    public func delete(forKey key: String) throws {
        do {
            try writer.delete(forKey: key)
        } catch let error as KeychainError {
            errorHandler.handle(error: error, forKey: key, operation: "delete")
            throw error
        } catch {
            errorHandler.handle(error: .unhandledError(status: -1), forKey: key, operation: "delete - unexpected error type")
            throw error
        }
    }

    // MARK: - KeychainEncryptor

    public func encrypt(_ data: Data) throws -> Data {
        do {
            return try encryptor.encrypt(data)
        } catch let error as KeychainError {
            errorHandler.handle(error: error, forKey: nil, operation: "encrypt")
            throw error
        } catch {
            errorHandler.handle(error: .unhandledError(status: -1), forKey: nil, operation: "encrypt - unexpected error type")
            throw error
        }
    }

    public func decrypt(_ data: Data) throws -> Data {
        do {
            return try encryptor.decrypt(data)
        } catch let error as KeychainError {
            errorHandler.handle(error: error, forKey: nil, operation: "decrypt")
            throw error
        } catch {
            errorHandler.handle(error: .unhandledError(status: -1), forKey: nil, operation: "decrypt - unexpected error type")
            throw error
        }
    }
}
