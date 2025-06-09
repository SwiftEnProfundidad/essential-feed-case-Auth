import Foundation

public struct UserLoginConfiguration {
    public let maxFailedAttempts: Int
    public let lockoutDuration: TimeInterval
    public let tokenDuration: TimeInterval

    public init(maxFailedAttempts: Int, lockoutDuration: TimeInterval, tokenDuration: TimeInterval) {
        self.maxFailedAttempts = maxFailedAttempts
        self.lockoutDuration = lockoutDuration
        self.tokenDuration = tokenDuration
    }
}
