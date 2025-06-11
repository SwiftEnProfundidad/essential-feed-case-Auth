import EssentialFeed
import Foundation

final class FailedLoginAttemptsStoreSpy: FailedLoginAttemptsStore, FailedLoginAttemptsStoreCleaning {
    enum Message: Equatable {
        case getAttempts(String)
        case incrementAttempts(String)
        case resetAttempts(String)
        case lastAttemptTime(String)
        case clearAll
    }

    private(set) var messages = [Message]()
    var attemptsToReturn = 0
    var lastAttemptTimeToReturn: Date? = nil
    var clearAllError: Error?

    func getAttempts(for username: String) -> Int {
        messages.append(.getAttempts(username))
        return attemptsToReturn
    }

    func incrementAttempts(for username: String) async {
        messages.append(.incrementAttempts(username))
    }

    func resetAttempts(for username: String) async {
        messages.append(.resetAttempts(username))
    }

    func lastAttemptTime(for username: String) -> Date? {
        messages.append(.lastAttemptTime(username))
        return lastAttemptTimeToReturn
    }

    func clearAll() async throws {
        messages.append(.clearAll)
        if let error = clearAllError {
            throw error
        }
    }
}
