import Foundation

public enum PasswordRecoveryDependencyFactory {
    public static func makePasswordRecoveryAPI(httpClient: HTTPClient, baseURL: URL) -> PasswordRecoveryAPI {
        HTTPPasswordRecoveryAPI(httpClient: httpClient, baseURL: baseURL)
    }

    public static func makePasswordRecoveryRateLimiter() -> PasswordRecoveryRateLimiter {
        let store = InMemoryPasswordRecoveryRateLimitStore()
        return DefaultPasswordRecoveryRateLimiter(store: store, maxAttempts: 3, timeWindowMinutes: 15)
    }

    public static func makePasswordResetTokenManager() -> PasswordResetTokenManager {
        let store = PasswordResetTokenMemoryStore()
        let generator = CryptoKitPasswordResetTokenGenerator()
        return DefaultPasswordResetTokenManager(
            tokenReader: store,
            tokenWriter: store,
            tokenUpdater: store,
            tokenCleaner: store,
            tokenGenerator: generator
        )
    }

    public static func makePasswordRecoveryAuditLogger() -> PasswordRecoveryAuditLogger {
        PasswordRecoveryAuditMemoryStore()
    }

    public static func makeSecurePasswordRecoveryUseCase(httpClient: HTTPClient, baseURL: URL) -> UserPasswordRecoveryUseCase {
        let baseUseCase = RemoteUserPasswordRecoveryUseCase(
            api: makePasswordRecoveryAPI(httpClient: httpClient, baseURL: baseURL),
            rateLimiter: makePasswordRecoveryRateLimiter(),
            tokenManager: makePasswordResetTokenManager(),
            auditLogger: makePasswordRecoveryAuditLogger()
        )

        let securityValidationService = SimpleSecurityValidationService(
            botDetection: makeBotDetectionService(),
            captchaValidator: makeGoogleRecaptchaValidator(httpClient: httpClient)
        )
        let securityLogger = makeSecurityEventLogger()

        return SecurePasswordRecoveryUseCase(
            baseUseCase: baseUseCase,
            securityValidationService: securityValidationService,
            securityLogger: securityLogger
        )
    }

    private static func makeGoogleRecaptchaValidator(httpClient: HTTPClient) -> CaptchaValidator {
        let secretKey = ProcessInfo.processInfo.environment["RECAPTCHA_SECRET_KEY"] ?? "test-secret-key"
        return GoogleRecaptchaValidator(secretKey: secretKey, httpClient: httpClient)
    }

    private static func makeBotDetectionService() -> BotDetectionService {
        BasicBotDetectionService()
    }

    private static func makeSecurityEventLogger() -> SecurityEventLogger {
        let auditLogger = makePasswordRecoveryAuditLogger()
        return DefaultSecurityEventLogger(auditLogger: auditLogger)
    }
}

public struct CaptchaConfiguration {
    public let provider: CaptchaProvider

    public init(provider: CaptchaProvider) {
        self.provider = provider
    }
}

public enum CaptchaProvider {
    case googleRecaptcha(secretKey: String)
}

private final class SimpleSecurityValidationService: SecurityValidationService {
    private let botDetection: BotDetectionService
    private let captchaValidator: CaptchaValidator

    init(botDetection: BotDetectionService, captchaValidator: CaptchaValidator) {
        self.botDetection = botDetection
        self.captchaValidator = captchaValidator
    }

    func validateSecurityRequirements(
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
            if let captchaResponse {
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
