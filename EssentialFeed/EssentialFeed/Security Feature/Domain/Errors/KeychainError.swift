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
    case migrationFailedBadFormat
    case migrationFailedSaveError(Error)

    public static func == (lhs: KeychainError, rhs: KeychainError) -> Bool {
        switch (lhs, rhs) {
        case (.itemNotFound, .itemNotFound),
             (.duplicateItem, .duplicateItem),
             (.invalidItemFormat, .invalidItemFormat),
             (.interactionNotAllowed, .interactionNotAllowed),
             (.encryptionFailed, .encryptionFailed),
             (.decryptionFailed, .decryptionFailed),
             (.dataToStringConversionFailed, .dataToStringConversionFailed),
             (.stringToDataConversionFailed, .stringToDataConversionFailed),
             (.migrationFailedBadFormat, .migrationFailedBadFormat):
            true
        case let (.unhandledError(lhsStatus), .unhandledError(rhsStatus)):
            lhsStatus == rhsStatus
        case let (.migrationFailedSaveError(lhsError), .migrationFailedSaveError(rhsError)):
            String(describing: lhsError) == String(describing: rhsError)
        default:
            false
        }
    }
}
