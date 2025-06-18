import Foundation

public enum SecurityValidationResult: Equatable {
    case allowed
    case denied(SecurityEvent)
    case requiresCaptcha(SecurityEvent)
}

public protocol SecurityValidationService {
    func validateSecurityRequirements(
        email: String,
        ipAddress: String?,
        userAgent: String?,
        captchaResponse: String?,
        requestPattern: RequestPattern
    ) async throws -> SecurityValidationResult
}
