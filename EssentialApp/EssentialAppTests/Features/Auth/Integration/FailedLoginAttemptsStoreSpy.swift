import EssentialFeed
import Foundation

public final class FailedLoginAttemptsStoreSpy: FailedLoginAttemptsStore {
    public enum Message: Equatable {
        case getAttempts(username: String)
        case incrementAttempts(username: String)
        case resetAttempts(username: String)
        case lastAttemptTime(username: String)
    }

    public private(set) var messages = [Message]()
    private var attemptsForUser: [String: Int] = [:]
    private var lastAttemptTimes: [String: Date] = [:]

    public init() {}

    public func getAttempts(for username: String) -> Int {
        messages.append(.getAttempts(username: username))
        return attemptsForUser[username, default: 0]
    }

    public func incrementAttempts(for username: String) async {
        messages.append(.incrementAttempts(username: username))
        attemptsForUser[username, default: 0] += 1
        lastAttemptTimes[username] = Date()
    }

    public func resetAttempts(for username: String) async {
        messages.append(.resetAttempts(username: username))
        attemptsForUser[username] = 0
        lastAttemptTimes.removeValue(forKey: username)
    }

    public func lastAttemptTime(for username: String) -> Date? {
        messages.append(.lastAttemptTime(username: username))
        return lastAttemptTimes[username]
    }

    // Helper properties for tests
    public var incrementAttemptsCallCount: Int {
        messages.filter { if case .incrementAttempts = $0 { return true } else { return false } }.count
    }

    public var resetAttemptsCallCount: Int {
        messages.filter { if case .resetAttempts = $0 { return true } else { return false } }.count
    }

    public var capturedUsernames: [String] {
        messages.compactMap {
            switch $0 {
            case let .getAttempts(username): return username
            case let .incrementAttempts(username): return username
            case let .resetAttempts(username): return username
            case let .lastAttemptTime(username): return username
            }
        }
    }

    public var attempts: [String: Int] {
        attemptsForUser
    }
}
