import Foundation

public struct AccountLockedError: LoginErrorType, Equatable {
    public let username: String
    public let remainingLockTime: TimeInterval

    public init(username: String, remainingLockTime: TimeInterval) {
        self.username = username
        self.remainingLockTime = remainingLockTime
    }

    public func errorMessage() -> String {
        let minutes = Int(ceil(remainingLockTime / 60))
        return "Account temporarily locked due to multiple failed attempts. Please try again in \(minutes) minute\(minutes == 1 ? "" : "s")."
    }
}
