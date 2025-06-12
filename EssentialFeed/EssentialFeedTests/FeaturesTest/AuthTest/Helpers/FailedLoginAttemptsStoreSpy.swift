import EssentialFeed
import Foundation

public final class FailedLoginAttemptsStoreSpy: FailedLoginAttemptsStore, FailedLoginAttemptsStoreCleaning {
    public enum Message: Equatable {
        case getAttempts(String)
        case incrementAttempts(String)
        case resetAttempts(String)
        case lastAttemptTime(String)
        case clearAll
    }

    public private(set) var messages = [Message]()
    public var attemptsToReturn = 0
    public var lastAttemptTimeToReturn: Date? = nil
    public var clearAllError: Error?

    public init() {} // Asegurar que sea público

    public func getAttempts(for username: String) -> Int {
        messages.append(.getAttempts(username))
        return attemptsToReturn
    }

    public func incrementAttempts(for username: String) async {
        messages.append(.incrementAttempts(username))
        // Normalmente aquí se modificaría attemptsToReturn, pero el spy no lo hace.
        // Si se espera que lo haga, se debe añadir esa lógica.
    }

    public func resetAttempts(for username: String) async {
        messages.append(.resetAttempts(username))
        // Normalmente aquí se modificaría attemptsToReturn para ese username,
        // pero este spy tiene un attemptsToReturn global.
    }

    public func lastAttemptTime(for username: String) -> Date? {
        messages.append(.lastAttemptTime(username))
        return lastAttemptTimeToReturn
    }

    public func clearAll() async throws {
        messages.append(.clearAll)
        if let error = clearAllError {
            throw error
        }
        // ADDED: Reset internal state
        attemptsToReturn = 0
        lastAttemptTimeToReturn = nil
    }
}
