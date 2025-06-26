import EssentialFeed
import Foundation

public final class TimeControlledFailedLoginAttemptsStoreSpy: FailedLoginAttemptsStore {
    private var attemptsForUser: [String: Int] = [:]
    private var lastAttemptTimes: [String: Date] = [:]
    private var resetCallCount = 0
    private var incrementCallCount = 0
    private let timeProvider: () -> Date

    public init(timeProvider: @escaping () -> Date = { Date() }) {
        self.timeProvider = timeProvider
    }

    public func getAttempts(for username: String) -> Int {
        return attemptsForUser[username, default: 0]
    }

    public func incrementAttempts(for username: String) async {
        attemptsForUser[username, default: 0] += 1
        lastAttemptTimes[username] = timeProvider()
        incrementCallCount += 1
    }

    public func resetAttempts(for username: String) async {
        attemptsForUser[username] = 0
        lastAttemptTimes.removeValue(forKey: username)
        resetCallCount += 1
    }

    public func lastAttemptTime(for username: String) -> Date? {
        return lastAttemptTimes[username]
    }

    // Helper properties for tests
    public var incrementAttemptsCallCount: Int {
        incrementCallCount
    }

    public var resetAttemptsCallCount: Int {
        resetCallCount
    }

    public var capturedUsernames: [String] {
        Array(attemptsForUser.keys)
    }

    public var attempts: [String: Int] {
        attemptsForUser
    }
}
