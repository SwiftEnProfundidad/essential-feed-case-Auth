import Foundation
import Security

public final class KeychainManager: @unchecked Sendable {
    private let reader: KeychainReader
    private let writer: KeychainWriter
    private let encryptor: KeychainEncryptor
    private let errorHandler: KeychainErrorHandling
    private let migrationManager: KeychainMigrationManager
    private let queue = DispatchQueue(
        label: "com.essentialfeed.keychain.manager", attributes: .concurrent
    )

    public init(
        reader: KeychainReader,
        writer: KeychainWriter,
        encryptor: KeychainEncryptor,
        errorHandler: KeychainErrorHandling
    ) {
        self.reader = reader
        self.writer = writer
        self.encryptor = encryptor
        self.errorHandler = errorHandler
        self.migrationManager = KeychainMigrationManager(
            encryptor: encryptor,
            writer: writer,
            errorHandler: errorHandler
        )
    }

    // MARK: - Private Methods

    private func loadRawData(forKey key: String) throws -> Data? {
        try queue.sync {
            try reader.load(forKey: key)
        }
    }

    private func decryptData(_ data: Data, forKey _: String) throws -> Data {
        try queue.sync {
            try encryptor.decrypt(data)
        }
    }

    private func saveEncryptedData(_ data: Data, forKey key: String) throws {
        let encryptedData = try encryptor.encrypt(data)
        try writer.save(data: encryptedData, forKey: key)
    }

    private func performKeychainOperation<T>(
        operation _: String,
        forKey _: String?,
        action: () throws -> T,
        errorHandler: (KeychainError) throws -> Void,
        unexpectedErrorHandler: () throws -> Void
    ) rethrows -> T {
        do {
            return try action()
        } catch let error as KeychainError {
            try errorHandler(error)
            throw error
        } catch {
            try unexpectedErrorHandler()
            throw error
        }
    }
}

// MARK: - KeychainReader

extension KeychainManager: KeychainReader {
    public func load(forKey key: String) throws -> Data? {
        try queue.sync {
            do {
                guard let rawData = try loadRawData(forKey: key) else {
                    return nil
                }

                do {
                    return try decryptData(rawData, forKey: key)
                } catch KeychainError.decryptionFailed {
                    return try migrationManager.attemptMigration(for: rawData, key: key)
                }
            } catch let error as KeychainError {
                errorHandler.handle(error: error, forKey: key, operation: "load (decrypt)")
                throw error
            } catch {
                errorHandler.handleUnexpectedError(forKey: key, operation: "load (decrypt)")
                throw error
            }
        }
    }
}

// MARK: - KeychainWriter

extension KeychainManager: KeychainWriter {
    public func save(data: Data, forKey key: String) throws {
        try queue.sync(flags: .barrier) {
            try performKeychainOperation(
                operation: "save",
                forKey: key,
                action: { try saveEncryptedData(data, forKey: key) },
                errorHandler: { error in
                    errorHandler.handle(error: error, forKey: key, operation: "save")
                    throw error
                },
                unexpectedErrorHandler: {
                    errorHandler.handleUnexpectedError(forKey: key, operation: "save")
                }
            )
        }
    }

    public func delete(forKey key: String) throws {
        try queue.sync(flags: .barrier) {
            try performKeychainOperation(
                operation: "delete",
                forKey: key,
                action: { try writer.delete(forKey: key) },
                errorHandler: { error in
                    errorHandler.handle(error: error, forKey: key, operation: "delete")
                    throw error
                },
                unexpectedErrorHandler: {
                    errorHandler.handleUnexpectedError(forKey: key, operation: "delete")
                }
            )
        }
    }
}

// MARK: - KeychainEncryptor

extension KeychainManager: KeychainEncryptor {
    public func encrypt(_ data: Data) throws -> Data {
        try queue.sync {
            try performKeychainOperation(
                operation: "encrypt",
                forKey: nil,
                action: { try encryptor.encrypt(data) },
                errorHandler: { error in
                    errorHandler.handle(error: error, forKey: nil, operation: "encrypt")
                    throw error
                },
                unexpectedErrorHandler: {
                    errorHandler.handleUnexpectedError(forKey: nil, operation: "encrypt")
                }
            )
        }
    }

    public func decrypt(_ data: Data) throws -> Data {
        try queue.sync {
            try performKeychainOperation(
                operation: "decrypt",
                forKey: nil,
                action: { try encryptor.decrypt(data) },
                errorHandler: { error in
                    errorHandler.handle(error: error, forKey: nil, operation: "decrypt")
                    throw error
                },
                unexpectedErrorHandler: {
                    errorHandler.handleUnexpectedError(forKey: nil, operation: "decrypt")
                }
            )
        }
    }
}
