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

    public static func makeSecurePasswordRecoveryUseCase(
        httpClient: HTTPClient,
        baseURL: URL,
        captchaConfiguration: CaptchaConfiguration? = nil
    ) -> UserPasswordRecoveryUseCase {
        let baseUseCase = RemoteUserPasswordRecoveryUseCase(
            api: makePasswordRecoveryAPI(httpClient: httpClient, baseURL: baseURL),
            rateLimiter: makePasswordRecoveryRateLimiter(),
            tokenManager: makePasswordResetTokenManager(),
            auditLogger: makePasswordRecoveryAuditLogger()
        )

        let securityValidationService = makeSecurityValidationService(
            httpClient: httpClient,
            captchaConfiguration: captchaConfiguration
        )
        let securityLogger = makeSecurityEventLogger()

        return SecurePasswordRecoveryUseCase(
            baseUseCase: baseUseCase,
            securityValidationService: securityValidationService,
            securityLogger: securityLogger
        )
    }

    private static func makeSecurityValidationService(
        httpClient: HTTPClient,
        captchaConfiguration: CaptchaConfiguration?
    ) -> SecurityValidationService {
        let botDetection = makeBotDetectionService()
        let captchaValidator = captchaConfiguration.map {
            makeCaptchaValidator(httpClient: httpClient, configuration: $0)
        }

        return DefaultSecurityValidationService(
            botDetection: botDetection,
            captchaValidator: captchaValidator
        )
    }

    private static func makeCaptchaValidator(
        httpClient: HTTPClient,
        configuration: CaptchaConfiguration
    ) -> CaptchaValidator {
        switch configuration.provider {
        case let .googleRecaptcha(secretKey):
            return GoogleRecaptchaValidator(secretKey: secretKey, httpClient: httpClient)
        }
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
