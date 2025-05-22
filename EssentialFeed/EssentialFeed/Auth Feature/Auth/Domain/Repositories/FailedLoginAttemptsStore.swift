import Foundation

public protocol FailedLoginAttemptsReader: AnyObject {
    func getAttempts(for username: String) -> Int
    func lastAttemptTime(for username: String) -> Date?
}

public protocol FailedLoginAttemptsWriter: AnyObject {
    func incrementAttempts(for username: String) async
    func resetAttempts(for username: String) async
}

public typealias FailedLoginAttemptsStore = FailedLoginAttemptsReader & FailedLoginAttemptsWriter
