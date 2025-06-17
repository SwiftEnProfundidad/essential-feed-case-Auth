import EssentialFeed
import Foundation
import os

public final class KeychainErrorHandlerSpy: KeychainErrorHandler {
    public enum Message: Equatable {
        case handle(error: KeychainError, key: String?, operation: String)
        case handleUnexpectedError(key: String?, operation: String)
    }

    private let lock = OSAllocatedUnfairLock()
    private var _messages = [Message]()

    public var messages: [Message] {
        lock.withLock { _messages }
    }

    public var handledErrors: [Message] {
        lock.withLock { _messages }
    }

    public init() {}

    public func handle(error: KeychainError, forKey key: String?, operation: String) {
        lock.withLock {
            _messages.append(.handle(error: error, key: key, operation: operation))
        }
    }

    public func clearMessages() {
        lock.withLock {
            _messages.removeAll()
        }
    }

    public func handleUnexpectedError(forKey key: String?, operation: String) {
        lock.withLock {
            _messages.append(.handleUnexpectedError(key: key, operation: operation))
        }
    }
}
