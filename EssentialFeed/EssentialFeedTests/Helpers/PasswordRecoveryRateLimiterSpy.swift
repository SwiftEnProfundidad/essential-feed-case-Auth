import EssentialFeed
import Foundation

public final class PasswordRecoveryRateLimiterSpy: PasswordRecoveryRateLimiter {
    public var stubbedValidationResult: Result<Void, PasswordRecoveryError> = .success(())
    public var recordedAttempts: [(email: String, ipAddress: String?)] = []

    public init() {}

    public func isAllowed(for _: String) -> Result<Void, PasswordRecoveryError> {
        stubbedValidationResult
    }

    public func recordAttempt(for email: String, ipAddress: String?) {
        recordedAttempts.append((email: email, ipAddress: ipAddress))
    }
}
