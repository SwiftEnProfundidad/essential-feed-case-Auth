import Foundation

public protocol PasswordRecoveryAttemptReader {
    func getAttempts(for email: String) -> [PasswordRecoveryAttempt]
}

public protocol PasswordRecoveryAttemptWriter {
    func recordAttempt(_ attempt: PasswordRecoveryAttempt)
}

public protocol PasswordRecoveryAttemptCleaner {
    func clearAttempts(for email: String)
}

public protocol PasswordRecoveryRateLimitStore: PasswordRecoveryAttemptReader, PasswordRecoveryAttemptWriter, PasswordRecoveryAttemptCleaner {}

public protocol PasswordRecoveryRateLimitValidator {
    func isAllowed(for email: String) -> Result<Void, PasswordRecoveryError>
}

public protocol PasswordRecoveryAttemptTracker {
    func recordAttempt(for email: String, ipAddress: String?)
}

public protocol PasswordRecoveryRateLimiter: PasswordRecoveryRateLimitValidator, PasswordRecoveryAttemptTracker {}
