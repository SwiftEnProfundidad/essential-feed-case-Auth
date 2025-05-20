import EssentialFeed // Import your main module to access KeychainError and KeychainErrorHandler
import Foundation

// Ensure KeychainError and KeychainErrorHandler are public and accessible from the test target.

public final class KeychainErrorHandlerSpy: KeychainErrorHandler {
    public enum Message: Equatable {
        case handled(error: KeychainError, key: String?, operation: String)
    }

    public private(set) var receivedMessages = [Message]()

    public init() {}

    public func handle(error: KeychainError, forKey key: String?, operation: String) {
        receivedMessages.append(.handled(error: error, key: key, operation: operation))
    }

    // Helper to clear messages for subsequent test assertions if needed
    public func clearMessages() {
        receivedMessages.removeAll()
    }

    // Helper to simulate specific behavior if needed in more complex tests,
    // for now, just recording is enough.
}
