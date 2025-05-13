
import EssentialFeed
import Foundation

public final class FailedLoginAttemptsStoreSpy: FailedLoginAttemptsStore {
    public private(set) var lastResetCount = 0
    public private(set) var getAttemptsCallCount = 0
    public private(set) var incrementAttemptsCallCount = 0
    public private(set) var resetAttemptsCallCount = 0
    public private(set) var capturedUsernames = [String]()
    private var attempts: [String: Int] = [:]
    private var lastAttemptTimes: [String: Date] = [:]

    public func getAttempts(for username: String) -> Int {
        _ = attempts[username, default: 0]
        getAttemptsCallCount += 1
        capturedUsernames.append(username)
        return attempts[username, default: 0]
    }

    public func incrementAttempts(for username: String) {
        incrementAttemptsCallCount += 1
        capturedUsernames.append(username)
        attempts[username, default: 0] += 1
        lastAttemptTimes[username] = Date()
    }

    public func resetAttempts(for username: String) {
        lastResetCount = incrementAttemptsCallCount
        resetAttemptsCallCount += 1
        capturedUsernames.append(username)
        attempts[username] = 0
        lastAttemptTimes[username] = nil
    }

    public var incrementAttemptsSinceLastReset: Int {
        _ = incrementAttemptsCallCount - lastResetCount
        return incrementAttemptsCallCount - lastResetCount
    }

    public func lastAttemptTime(for username: String) -> Date? {
        lastAttemptTimes[username]
    }
}
