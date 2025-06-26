import Foundation

public struct UserLoginConfiguration {
    public let maxFailedAttempts: Int
    public let lockoutDuration: TimeInterval
    public let tokenDuration: TimeInterval
    public let captchaSecretKey: String

    public init(
        maxFailedAttempts: Int, lockoutDuration: TimeInterval, tokenDuration: TimeInterval,
        captchaSecretKey: String
    ) {
        self.maxFailedAttempts = maxFailedAttempts
        self.lockoutDuration = lockoutDuration
        self.tokenDuration = tokenDuration
        self.captchaSecretKey = captchaSecretKey
    }
}
