import Foundation

public enum CaptchaError: Error, Equatable {
    case invalidResponse
    case networkError
    case serviceUnavailable
    case rateLimitExceeded
    case malformedRequest
    case unknownError(String)
}

public extension PasswordRecoveryError {
    static let captchaRequired = PasswordRecoveryError.rateLimitExceeded(retryAfterSeconds: 0)
    static let captchaFailed = PasswordRecoveryError.rateLimitExceeded(retryAfterSeconds: 30)
    static let captchaValidationError = PasswordRecoveryError.rateLimitExceeded(retryAfterSeconds: 60)
    static let botDetected = PasswordRecoveryError.rateLimitExceeded(retryAfterSeconds: 300)
}
