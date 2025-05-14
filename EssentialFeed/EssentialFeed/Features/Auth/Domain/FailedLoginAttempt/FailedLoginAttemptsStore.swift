
import Foundation

public protocol FailedLoginAttemptsReader {
    func getAttempts(for username: String) -> Int
    func lastAttemptTime(for username: String) -> Date?
}

public protocol FailedLoginAttemptsWriter {
    func incrementAttempts(for username: String)
    func resetAttempts(for username: String)
}

public typealias FailedLoginAttemptsStore = FailedLoginAttemptsReader & FailedLoginAttemptsWriter
