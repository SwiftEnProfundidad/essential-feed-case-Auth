import Foundation

public final class DefaultSecurityValidationService: SecurityValidationService {
    private let botDetection: BotDetectionService
    private let captchaValidator: CaptchaValidator?

    public init(botDetection: BotDetectionService, captchaValidator: CaptchaValidator? = nil) {
        self.botDetection = botDetection
        self.captchaValidator = captchaValidator
    }

    public func validateSecurityRequirements(
        email _: String,
        ipAddress: String?,
        userAgent: String?,
        captchaResponse: String?,
        requestPattern: RequestPattern
    ) async throws -> SecurityValidationResult {
        let botResult = botDetection.analyzeRequest(
            ipAddress: ipAddress,
            userAgent: userAgent,
            requestPattern: requestPattern
        )

        switch botResult {
        case let .bot(confidence):
            return .denied(.botDetected(confidence: confidence))
        case let .suspicious(reason):
            if let captchaResponse, let captchaValidator {
                let captchaResult = try await captchaValidator.validateCaptcha(
                    response: captchaResponse,
                    clientIP: ipAddress
                )

                if !captchaResult.isValid {
                    return .denied(.captchaFailed)
                }

                if let score = captchaResult.score, score < 0.5 {
                    return .denied(.lowCaptchaScore(score: score))
                }

                return .allowed
            } else {
                return .requiresCaptcha(.suspiciousActivity(reason: reason))
            }
        case .human:
            return .allowed
        }
    }
}
