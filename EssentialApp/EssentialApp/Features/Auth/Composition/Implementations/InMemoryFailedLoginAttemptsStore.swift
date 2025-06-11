@preconcurrency import EssentialFeed
import Foundation

// MARK: - In Memory Failed Login Store for Demo

final class InMemoryFailedLoginAttemptsStore: FailedLoginAttemptsStore, @unchecked Sendable {
    private var attempts: [String: Int] = [:]
    private var lastAttemptTimes: [String: Date] = [:]

    func getAttempts(for username: String) -> Int {
        attempts[username] ?? 0
    }

    func incrementAttempts(for username: String) async {
        attempts[username] = getAttempts(for: username) + 1
        lastAttemptTimes[username] = Date()
    }

    func resetAttempts(for username: String) async {
        attempts[username] = 0
        lastAttemptTimes[username] = nil
    }

    func lastAttemptTime(for username: String) -> Date? {
        lastAttemptTimes[username]
    }
}
