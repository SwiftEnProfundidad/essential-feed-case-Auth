import Foundation
import os.log

public final class LoggingKeychainErrorHandler: KeychainErrorHandler {
    private static let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.essentialfeed.app", category: "KeychainError")

    public init() {}

    public func handle(error: KeychainError, forKey key: String?, operation: String) {
        let keyDescription = key ?? "N/A"
        let logMessage = """
        Keychain Operation Failed:
        Operation: \(operation)
        Key: \(keyDescription)
        Error: \(error)
        Details: \(error.localizedDescription)
        """
        os_log("%@", log: LoggingKeychainErrorHandler.logger, type: .error, logMessage)
    }

    public func handleUnexpectedError(forKey key: String?, operation: String) {
        let keyDescription = key ?? "N/A"
        let logMessage = """
        Keychain Operation Failed with Unexpected Error:
        Operation: \(operation)
        Key: \(keyDescription)
        Error: An unexpected, non-KeychainError type was thrown.
        """
        os_log("%@", log: LoggingKeychainErrorHandler.logger, type: .fault, logMessage)
    }
}
