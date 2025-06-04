import Foundation

final class KeychainMigrationManager {
    private let encryptor: KeychainEncryptor
    private let writer: KeychainWriter
    private let errorHandler: KeychainErrorHandling

    init(
        encryptor: KeychainEncryptor,
        writer: KeychainWriter,
        errorHandler: KeychainErrorHandling
    ) {
        self.encryptor = encryptor
        self.writer = writer
        self.errorHandler = errorHandler
    }

    func attemptMigration(for rawData: Data, key: String) throws -> Data {
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
    }
}
