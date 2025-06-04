import EssentialFeed
import Foundation

public final class KeychainErrorHandlerSpy: KeychainErrorHandling {
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

    public func handleUnexpectedError(forKey key: String?, operation: String) {
        let error = KeychainError.unhandledError(-1)
        handle(error: error, forKey: key, operation: "\(operation) - unexpected error type")
    }
}
