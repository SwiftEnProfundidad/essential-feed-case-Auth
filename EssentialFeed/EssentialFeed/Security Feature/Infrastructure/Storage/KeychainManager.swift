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
        let rawDataFromKeychain: Data?
        do {
            rawDataFromKeychain = try reader.load(forKey: key)
        } catch let error as KeychainError {
            errorHandler.handle(error: error, forKey: key, operation: "load (read from keychain)")
            throw error
        } catch {
            errorHandler.handle(error: .unhandledError(status: -1), forKey: key, operation: "load (read from keychain) - unexpected error type")
            throw error
        }

        guard let rawData = rawDataFromKeychain else {
            return nil
        }

        do {
            let decryptedData = try encryptor.decrypt(rawData)
            return decryptedData
        } catch KeychainError.decryptionFailed {
            guard let plainTextTokenString = String(data: rawData, encoding: .utf8) else {
                errorHandler.handle(error: .migrationFailedBadFormat, forKey: key, operation: "load (migration attempt - bad format)")
                throw KeychainError.migrationFailedBadFormat
            }

            guard let plainTextTokenData = plainTextTokenString.data(using: .utf8) else {
                errorHandler.handle(error: .stringToDataConversionFailed, forKey: key, operation: "load (migration - converting string back to data)")
                throw KeychainError.stringToDataConversionFailed
            }

            do {
                let migratedEncryptedData = try encryptor.encrypt(plainTextTokenData)
                try writer.save(data: migratedEncryptedData, forKey: key)
                errorHandler.handle(error: .decryptionFailed, forKey: key, operation: "load (migration successful: old token was plain text, now encrypted and saved)")
                return plainTextTokenData
            } catch let saveError {
                errorHandler.handle(error: .migrationFailedSaveError(saveError), forKey: key, operation: "load (migration save failed)")
                throw KeychainError.migrationFailedSaveError(saveError)
            }
        } catch let otherDecryptionError as KeychainError {
            errorHandler.handle(error: otherDecryptionError, forKey: key, operation: "load (decrypt)")
            throw otherDecryptionError
        } catch {
            errorHandler.handle(error: .unhandledError(status: -1), forKey: key, operation: "load (decrypt) - unexpected error type")
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
