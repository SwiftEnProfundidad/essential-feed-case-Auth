import Foundation

public struct LoginSecurityConfiguration {
    public let maxAttempts: Int
    public let blockDuration: TimeInterval
    public let captchaThreshold: Int

    public init(
        maxAttempts: Int,
        blockDuration: TimeInterval,
        captchaThreshold: Int
    ) {
        self.maxAttempts = maxAttempts
        self.blockDuration = blockDuration
        self.captchaThreshold = captchaThreshold
    }

    public static var `default`: LoginSecurityConfiguration {
        LoginSecurityConfiguration(
            maxAttempts: 5,
            blockDuration: 300,
            captchaThreshold: 3
        )
    }

    public static var strict: LoginSecurityConfiguration {
        LoginSecurityConfiguration(
            maxAttempts: 3,
            blockDuration: 600,
            captchaThreshold: 2
        )
    }

    public static var lenient: LoginSecurityConfiguration {
        LoginSecurityConfiguration(
            maxAttempts: 10,
            blockDuration: 60,
            captchaThreshold: 5
        )
    }
}
