@preconcurrency import EssentialFeed
import Foundation

// MARK: - Simple Error Handler

final class LoggingKeychainErrorHandler: KeychainErrorHandling, @unchecked Sendable {
    func handle(error: KeychainError, forKey key: String?, operation: String) {
        print("Keychain error in \(operation) for key \(key ?? "unknown"): \(error)")
    }

    func handleUnexpectedError(forKey key: String?, operation: String) {
        print("Unexpected keychain error in \(operation) for key \(key ?? "unknown")")
    }
}
