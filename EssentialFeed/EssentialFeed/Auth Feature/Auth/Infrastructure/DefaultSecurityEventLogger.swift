import Foundation

public final class DefaultSecurityEventLogger: SecurityEventLogger {
    private let auditLogger: PasswordRecoveryAuditLogger

    public init(auditLogger: PasswordRecoveryAuditLogger) {
        self.auditLogger = auditLogger
    }

    public func logSecurityEvent(_ event: SecurityEvent, email: String, ipAddress: String?, userAgent: String?) async {
        let outcome = mapSecurityEventToOutcome(event)
        let errorDetails = extractErrorDetails(from: event)

        let auditLog = PasswordRecoveryAuditLog(
            email: email,
            ipAddress: ipAddress,
            userAgent: userAgent,
            outcome: outcome,
            errorDetails: errorDetails
        )

        try? await auditLogger.logRecoveryAttempt(auditLog)
    }

    private func mapSecurityEventToOutcome(_ event: SecurityEvent) -> PasswordRecoveryOutcome {
        switch event {
        case .botDetected:
            .botDetected
        case .suspiciousActivity:
            .suspiciousActivity
        case .captchaFailed, .lowCaptchaScore:
            .captchaFailed
        case .captchaError:
            .captchaError
        case .captchaRequired:
            .captchaRequired
        }
    }

    private func extractErrorDetails(from event: SecurityEvent) -> String? {
        switch event {
        case let .botDetected(confidence):
            "Bot detected with confidence: \(confidence)"
        case let .suspiciousActivity(reason):
            "Suspicious activity: \(reason)"
        case let .lowCaptchaScore(score):
            "Low CAPTCHA score: \(score)"
        case let .captchaError(error):
            "CAPTCHA error: \(error)"
        case .captchaFailed, .captchaRequired:
            nil
        }
    }
}

public extension PasswordRecoveryOutcome {
    static let botDetected = PasswordRecoveryOutcome.rateLimitExceeded
    static let suspiciousActivity = PasswordRecoveryOutcome.rateLimitExceeded
    static let captchaFailed = PasswordRecoveryOutcome.rateLimitExceeded
    static let captchaError = PasswordRecoveryOutcome.rateLimitExceeded
    static let captchaRequired = PasswordRecoveryOutcome.rateLimitExceeded
}
