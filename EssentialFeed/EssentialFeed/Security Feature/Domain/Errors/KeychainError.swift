import Foundation
import os.log

public protocol KeychainErrorProtocol: Error, Equatable {
    var errorDescription: String { get }
}

public enum KeychainError: KeychainErrorProtocol {
    case itemNotFound
    case duplicateItem
    case invalidItemFormat
    case interactionNotAllowed
    case unhandledError(OSStatus)
    case dataConversionFailed
    case stringToDataConversionFailed
    case dataTooLarge(Int, Int)
    case invalidKeyFormat
    case decryptionFailed
    case migrationFailedBadFormat
    case migrationFailedSaveError(Error)

    public var errorDescription: String {
        switch self {
        case .itemNotFound: "Item not found"
        case .duplicateItem: "Duplicate item"
        case .invalidItemFormat: "Invalid item format"
        case .interactionNotAllowed: "Interaction not allowed"
        case let .unhandledError(status): "Unhandled error: \(status)"
        case .dataConversionFailed: "Data conversion failed"
        case .stringToDataConversionFailed: "Failed to convert string to data using UTF-8 encoding"
        case let .dataTooLarge(size, max):
            "Data too large: \(size) bytes (max: \(max))"
        case .invalidKeyFormat: "Invalid key format"
        case .decryptionFailed: "Decryption failed"
        case .migrationFailedBadFormat: "Migration failed: bad format"
        case let .migrationFailedSaveError(error): "Migration failed to save: \(error.localizedDescription)"
        }
    }

    public static func == (lhs: KeychainError, rhs: KeychainError) -> Bool {
        switch (lhs, rhs) {
        case (.itemNotFound, .itemNotFound): true
        case (.duplicateItem, .duplicateItem): true
        case (.invalidItemFormat, .invalidItemFormat): true
        case (.interactionNotAllowed, .interactionNotAllowed): true
        case let (.unhandledError(lhsStatus), .unhandledError(rhsStatus)):
            lhsStatus == rhsStatus
        case (.dataConversionFailed, .dataConversionFailed): true
        case (.stringToDataConversionFailed, .stringToDataConversionFailed): true
        case let (.dataTooLarge(lhsSize, lhsMax), .dataTooLarge(rhsSize, rhsMax)):
            lhsSize == rhsSize && lhsMax == rhsMax
        case (.invalidKeyFormat, .invalidKeyFormat): true
        case (.decryptionFailed, .decryptionFailed): true
        case (.migrationFailedBadFormat, .migrationFailedBadFormat): true
        case let (.migrationFailedSaveError(lhsError), .migrationFailedSaveError(rhsError)):
            (lhsError as NSError).isEqual(rhsError as NSError)
        default: false
        }
    }
}

public protocol KeychainErrorLogger {
    func logError(_ message: String, error: Error)
}

public final class OSLogger: KeychainErrorLogger {
    private let logger: OSLog

    public init(
        subsystem: String = Bundle.main.bundleIdentifier ?? "Keychain",
        category: String = "Keychain"
    ) {
        self.logger = OSLog(subsystem: subsystem, category: category)
    }

    public func logError(_ message: String, error: Error) {
        os_log(
            "%{public}@: %{public}@",
            log: logger,
            type: .error,
            message,
            error.localizedDescription
        )
    }
}
