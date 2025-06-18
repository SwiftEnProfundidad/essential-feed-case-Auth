import Foundation

public enum CaptchaErrorMapper {
    public static func mapToPasswordRecoveryError(_ captchaError: CaptchaError) -> PasswordRecoveryError {
        switch captchaError {
        case .invalidResponse:
            .rateLimitExceeded(retryAfterSeconds: 30)
        case .networkError:
            .network
        case .serviceUnavailable:
            .unknown
        case .rateLimitExceeded:
            .rateLimitExceeded(retryAfterSeconds: 60)
        case .malformedRequest:
            .unknown
        case .unknownError:
            .unknown
        }
    }

    public static func mapSecurityEventToError(_ event: SecurityEvent) -> PasswordRecoveryError {
        switch event {
        case .botDetected:
            .rateLimitExceeded(retryAfterSeconds: 300)
        case .suspiciousActivity:
            .rateLimitExceeded(retryAfterSeconds: 0)
        case .captchaFailed, .lowCaptchaScore:
            .rateLimitExceeded(retryAfterSeconds: 30)
        case .captchaError:
            .rateLimitExceeded(retryAfterSeconds: 60)
        case .captchaRequired:
            .rateLimitExceeded(retryAfterSeconds: 0)
        }
    }
}
