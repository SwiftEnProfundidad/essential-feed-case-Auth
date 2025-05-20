import Foundation

public enum KeychainError: Error, Equatable {
    case itemNotFound
    case duplicateItem
    case invalidItemFormat
    case interactionNotAllowed
    case unhandledError(status: OSStatus)
    case encryptionFailed
    case decryptionFailed
    case dataToStringConversionFailed
    case stringToDataConversionFailed
}
