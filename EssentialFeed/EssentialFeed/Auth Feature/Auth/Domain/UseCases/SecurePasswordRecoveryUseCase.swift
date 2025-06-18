import Foundation

public final class SecurePasswordRecoveryUseCase: UserPasswordRecoveryUseCase {
    private let baseUseCase: UserPasswordRecoveryUseCase
    private let securityValidationService: SecurityValidationService
    private let securityLogger: SecurityEventLogger

    public init(
        baseUseCase: UserPasswordRecoveryUseCase,
        securityValidationService: SecurityValidationService,
        securityLogger: SecurityEventLogger
    ) {
        self.baseUseCase = baseUseCase
        self.securityValidationService = securityValidationService
        self.securityLogger = securityLogger
    }

    public func recoverPassword(
        email: String,
        ipAddress: String? = nil,
        userAgent: String? = nil,
        completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void
    ) {
        recoverPasswordWithSecurity(
            email: email,
            ipAddress: ipAddress,
            userAgent: userAgent,
            captchaResponse: nil,
            completion: completion
        )
    }

    public func recoverPasswordWithSecurity(
        email: String,
        ipAddress: String?,
        userAgent: String?,
        captchaResponse: String?,
        completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void
    ) {
        Task {
            do {
                let securityResult = try await securityValidationService.validateSecurityRequirements(
                    email: email,
                    ipAddress: ipAddress,
                    userAgent: userAgent,
                    captchaResponse: captchaResponse,
                    requestPattern: .passwordRecovery
                )

                switch securityResult {
                case .allowed:
                    baseUseCase.recoverPassword(
                        email: email,
                        ipAddress: ipAddress,
                        userAgent: userAgent,
                        completion: completion
                    )
                case let .denied(reason):
                    await securityLogger.logSecurityEvent(reason, email: email, ipAddress: ipAddress, userAgent: userAgent)
                    let error = CaptchaErrorMapper.mapSecurityEventToError(reason)
                    completion(.failure(error))
                case let .requiresCaptcha(reason):
                    await securityLogger.logSecurityEvent(reason, email: email, ipAddress: ipAddress, userAgent: userAgent)
                    completion(.failure(.rateLimitExceeded(retryAfterSeconds: 0)))
                }
            } catch {
                await securityLogger.logSecurityEvent(.captchaError(error: error.localizedDescription), email: email, ipAddress: ipAddress, userAgent: userAgent)
                completion(.failure(.unknown))
            }
        }
    }
}
