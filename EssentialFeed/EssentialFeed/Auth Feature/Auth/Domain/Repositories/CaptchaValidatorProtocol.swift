import Foundation

public protocol CaptchaValidator {
    func validateCaptcha(response: String, clientIP: String?) async throws -> CaptchaValidationResult
}

public protocol BotDetectionService {
    func analyzeRequest(ipAddress: String?, userAgent: String?, requestPattern: RequestPattern) -> BotDetectionResult
}

public protocol SecurityEventLogger {
    func logSecurityEvent(_ event: SecurityEvent, email: String, ipAddress: String?, userAgent: String?) async
}
