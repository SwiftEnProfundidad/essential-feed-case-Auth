import EssentialFeed
import Foundation

public final class AnyFailedLoginAttemptStore: FailedLoginAttemptsStore {
    private let _getAttempts: (String) -> Int
    private let _incrementAttempts: (String) async -> Void
    private let _resetAttempts: (String) async -> Void
    private let _lastAttemptTime: (String) -> Date?

    public init(_ store: some FailedLoginAttemptsStore) {
        _getAttempts = store.getAttempts
        _incrementAttempts = store.incrementAttempts
        _resetAttempts = store.resetAttempts
        _lastAttemptTime = store.lastAttemptTime
    }

    public func getAttempts(for username: String) -> Int {
        _getAttempts(username)
    }

    public func incrementAttempts(for username: String) async {
        await _incrementAttempts(username)
    }

    public func resetAttempts(for username: String) async {
        await _resetAttempts(username)
    }

    public func lastAttemptTime(for username: String) -> Date? {
        _lastAttemptTime(username)
    }
}
