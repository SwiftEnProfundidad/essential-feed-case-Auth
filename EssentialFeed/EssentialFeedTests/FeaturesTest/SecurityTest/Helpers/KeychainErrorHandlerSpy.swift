import EssentialFeed
import Foundation

public final class KeychainErrorHandlerSpy: KeychainErrorHandler {
    public enum Message: Equatable {
        case handle(error: KeychainError, key: String?, operation: String)
        case handleUnexpectedError(key: String?, operation: String)
    }

    private let lock = NSLock()
    private var _messages = [Message]()

    public var messages: [Message] {
        lock.lock()
        defer { lock.unlock() }
        return _messages
    }

    public var handledErrors: [Message] {
        lock.lock()
        defer { lock.unlock() }
        return _messages
    }

    public init() {}

    public func handle(error: KeychainError, forKey key: String?, operation: String) {
        lock.lock()
        defer { lock.unlock() }
        _messages.append(.handle(error: error, key: key, operation: operation))
    }

    public func clearMessages() {
        lock.lock()
        defer { lock.unlock() }
        _messages.removeAll()
    }

    public func handleUnexpectedError(forKey key: String?, operation: String) {
        lock.lock()
        defer { lock.unlock() }
        _messages.append(.handleUnexpectedError(key: key, operation: operation))
    }
}
