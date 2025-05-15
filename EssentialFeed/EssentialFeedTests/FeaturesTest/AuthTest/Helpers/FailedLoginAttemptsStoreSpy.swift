
import EssentialFeed
import Foundation

final class FailedLoginAttemptsStoreSpy: FailedLoginAttemptsStore {
    enum Message: Equatable {
        case getAttempts(String)
        case incrementAttempts(String)
        case resetAttempts(String)
        case lastAttemptTime(String)
    }

    private(set) var messages = [Message]()
    var attemptsToReturn = 0
    var lastAttemptTimeToReturn: Date? = nil

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
}
