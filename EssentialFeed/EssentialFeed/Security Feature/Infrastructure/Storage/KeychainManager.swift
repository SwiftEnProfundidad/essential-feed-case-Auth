import Foundation
import Security

public final class KeychainManager: @unchecked Sendable, KeychainManaging {
    private let reader: KeychainReader
    private let writer: KeychainWriter
    private let encryptor: KeychainEncryptor
    private let errorHandler: KeychainErrorHandler
    private let migrationManager: KeychainMigrationManager
    private let queue = DispatchQueue(
        label: "com.essentialfeed.keychain.manager", attributes: .concurrent
    )

    public init(
        reader: KeychainReader,
        writer: KeychainWriter,
        encryptor: KeychainEncryptor,
        errorHandler: KeychainErrorHandler
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

    public func load(forKey key: String) throws -> Data? {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorHandler.handle(error: .invalidKeyFormat, forKey: key, operation: "load (empty key)")
            throw KeychainError.invalidKeyFormat
        }

        return try queue.sync {
            do {
                guard let rawData = try reader.load(forKey: key) else {
                    return nil
                }

                do {
                    return try decryptData(rawData, forKey: key)
                } catch KeychainError.decryptionFailed {
                    return try migrationManager.attemptMigration(for: rawData, key: key)
                } catch let decryptionError as KeychainError {
                    errorHandler.handle(error: decryptionError, forKey: key, operation: "load (decryption phase)")
                    throw decryptionError
                } catch {
                    errorHandler.handleUnexpectedError(forKey: key, operation: "load (decryption phase)")
                    throw error
                }
            } catch let error as KeychainError {
                if error != .decryptionFailed {
                    errorHandler.handle(error: error, forKey: key, operation: "load")
                }
                throw error
            } catch {
                errorHandler.handleUnexpectedError(forKey: key, operation: "load")
                throw error
            }
        }
    }

    public func save(data: Data, forKey key: String) throws {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorHandler.handle(error: .invalidKeyFormat, forKey: key, operation: "save (empty key)")
            throw KeychainError.invalidKeyFormat
        }

        try queue.sync(flags: .barrier) {
            try performKeychainOperation(
                operation: "save",
                forKey: key,
                action: {
                    let encryptedData = try encryptor.encrypt(data)
                    try writer.save(data: encryptedData, forKey: key)
                },
                errorHandler: { keychainError in
                    errorHandler.handle(error: keychainError, forKey: key, operation: "save")
                },
                unexpectedErrorHandler: {
                    errorHandler.handleUnexpectedError(forKey: key, operation: "save")
                }
            )
        }
    }

    public func delete(forKey key: String) throws {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorHandler.handle(error: .invalidKeyFormat, forKey: key, operation: "delete (empty key)")
            throw KeychainError.invalidKeyFormat
        }

        try queue.sync(flags: .barrier) {
            try performKeychainOperation(
                operation: "delete",
                forKey: key,
                action: {
                    try writer.delete(forKey: key)
                },
                errorHandler: { keychainError in
                    errorHandler.handle(error: keychainError, forKey: key, operation: "delete")
                },
                unexpectedErrorHandler: {
                    errorHandler.handleUnexpectedError(forKey: key, operation: "delete")
                }
            )
        }
    }
}
