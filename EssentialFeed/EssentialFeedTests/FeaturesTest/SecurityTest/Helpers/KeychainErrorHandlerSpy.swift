import EssentialFeed
import Foundation

public final class KeychainErrorHandlerSpy: KeychainErrorHandler {
    public enum Message: Equatable {
        case handled(error: KeychainError, key: String?, operation: String)
    }

    public private(set) var receivedMessages = [Message]()

    public init() {}

    public func handle(error: KeychainError, forKey key: String?, operation: String) {
        receivedMessages.append(.handled(error: error, key: key, operation: operation))
    }

    public func clearMessages() {
        receivedMessages.removeAll()
    }

    // Helper to simulate specific behavior if needed in more complex tests,
    // for now, just recording is enough.
}
