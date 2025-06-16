import EssentialFeed
import Foundation

public final class KeychainErrorHandlerSpy: KeychainErrorHandler {
    public enum Message: Equatable {
        case handle(error: KeychainError, key: String?, operation: String)
        case handleUnexpectedError(key: String?, operation: String)
    }

    public private(set) var messages = [Message]()

    public init() {}

    public func handle(error: KeychainError, forKey key: String?, operation: String) {
        messages.append(.handle(error: error, key: key, operation: operation))
    }

    public func clearMessages() {
        messages.removeAll()
    }

    public func handleUnexpectedError(forKey key: String?, operation: String) {
        messages.append(.handleUnexpectedError(key: key, operation: operation))
    }
}
