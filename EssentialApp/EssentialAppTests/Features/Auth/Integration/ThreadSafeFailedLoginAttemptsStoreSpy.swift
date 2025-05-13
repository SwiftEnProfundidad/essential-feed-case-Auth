
import EssentialFeed
import Foundation

public final class ThreadSafeFailedLoginAttemptsStoreSpy: FailedLoginAttemptsStore {
    private let queue = DispatchQueue(label: "ThreadSafeFailedLoginAttemptsStoreSpy.queue", attributes: .concurrent)
    private var _lastResetCount = 0
    private var _getAttemptsCallCount = 0
    private var _incrementAttemptsCallCount = 0
    private var _resetAttemptsCallCount = 0
    private var _capturedUsernames = [String]()
    private var _attempts: [String: Int] = [:]
    private var _lastAttemptTimes: [String: Date] = [:]

    public var lastResetCount: Int { queue.sync { _lastResetCount } }
    public var getAttemptsCallCount: Int { queue.sync { _getAttemptsCallCount } }
    public var incrementAttemptsCallCount: Int { queue.sync { _incrementAttemptsCallCount } }
    public var resetAttemptsCallCount: Int { queue.sync { _resetAttemptsCallCount } }
    public var capturedUsernames: [String] { queue.sync { _capturedUsernames } }
    public var attempts: [String: Int] { queue.sync { _attempts } }

    public func getAttempts(for username: String) -> Int {
        queue.sync(flags: .barrier) {
            _ = _attempts[username, default: 0]
            _getAttemptsCallCount += 1
            _capturedUsernames.append(username)
            return _attempts[username, default: 0]
        }
    }

    public func incrementAttempts(for username: String) {
        queue.sync(flags: .barrier) {
            _incrementAttemptsCallCount += 1
            _capturedUsernames.append(username)
            _attempts[username, default: 0] += 1
            _lastAttemptTimes[username] = Date()
        }
    }

    public func resetAttempts(for username: String) {
        queue.sync(flags: .barrier) {
            _lastResetCount = _incrementAttemptsCallCount
            _resetAttemptsCallCount += 1
            _capturedUsernames.append(username)
            _attempts[username] = 0
            _lastAttemptTimes[username] = nil
        }
    }

    public var incrementAttemptsSinceLastReset: Int {
        queue.sync { _incrementAttemptsCallCount - _lastResetCount }
    }

    public func lastAttemptTime(for username: String) -> Date? {
        queue.sync { _lastAttemptTimes[username] }
    }
}
