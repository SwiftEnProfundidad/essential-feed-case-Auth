import Foundation

public enum CaptchaErrorMapper {
    public static func mapToPasswordRecoveryError(_ captchaError: CaptchaError) -> PasswordRecoveryError {
        switch captchaError {
        case .invalidResponse:
            return .rateLimitExceeded(retryAfterSeconds: 30)
        case .networkError:
            return .network
        case .serviceUnavailable:
            return .unknown
        case .rateLimitExceeded:
            return .rateLimitExceeded(retryAfterSeconds: 60)
        case .malformedRequest:
            return .unknown
        case .unknownError:
            return .unknown
        }
    }

    public static func mapSecurityEventToError(_ event: SecurityEvent) -> PasswordRecoveryError {
        switch event {
        case .botDetected:
            return .rateLimitExceeded(retryAfterSeconds: 300)
        case .suspiciousActivity:
            return .rateLimitExceeded(retryAfterSeconds: 0)
        case .captchaFailed, .lowCaptchaScore:
            return .rateLimitExceeded(retryAfterSeconds: 30)
        case .captchaError:
            return .rateLimitExceeded(retryAfterSeconds: 60)
        case .captchaRequired:
            return .rateLimitExceeded(retryAfterSeconds: 0)
        }
    }
}
