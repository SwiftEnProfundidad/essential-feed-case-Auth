import Foundation

public protocol UserPasswordRecoveryUseCase {
    func recoverPassword(email: String, ipAddress: String?, userAgent: String?, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void)
}

public final class RemoteUserPasswordRecoveryUseCase: UserPasswordRecoveryUseCase {
    private let api: PasswordRecoveryAPI
    private let rateLimiter: PasswordRecoveryRateLimiter
    private let tokenManager: PasswordResetTokenManager
    private let auditLogger: PasswordRecoveryAuditLogger

    public init(api: PasswordRecoveryAPI, rateLimiter: PasswordRecoveryRateLimiter, tokenManager: PasswordResetTokenManager, auditLogger: PasswordRecoveryAuditLogger) {
        self.api = api
        self.rateLimiter = rateLimiter
        self.tokenManager = tokenManager
        self.auditLogger = auditLogger
    }

    public func recoverPassword(email: String, ipAddress: String? = nil, userAgent: String? = nil, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        guard emailPredicate.evaluate(with: trimmedEmail) else {
            completion(.failure(.invalidEmailFormat))
            Task { [weak self] in
                let auditLog = PasswordRecoveryAuditLog(email: trimmedEmail, ipAddress: ipAddress, userAgent: userAgent, outcome: .invalidEmailFormat)
                try? await self?.auditLogger.logRecoveryAttempt(auditLog)
            }
            return
        }

        switch rateLimiter.isAllowed(for: trimmedEmail) {
        case .success:
            rateLimiter.recordAttempt(for: trimmedEmail, ipAddress: ipAddress)

            api.recover(email: trimmedEmail) { [weak self] result in
                guard let self else { return }

                switch result {
                case .success:
                    do {
                        let resetToken = try self.tokenManager.generateResetToken(for: trimmedEmail)
                        let response = PasswordRecoveryResponse(message: "Password reset link sent to your email", resetToken: resetToken.token)
                        completion(.success(response))

                        Task { [weak self] in
                            let auditLog = PasswordRecoveryAuditLog(email: trimmedEmail, ipAddress: ipAddress, userAgent: userAgent, outcome: .success)
                            try? await self?.auditLogger.logRecoveryAttempt(auditLog)
                        }
                    } catch {
                        completion(.failure(.tokenGenerationFailed))
                        Task { [weak self] in
                            let auditLog = PasswordRecoveryAuditLog(email: trimmedEmail, ipAddress: ipAddress, userAgent: userAgent, outcome: .tokenGenerationFailed, errorDetails: error.localizedDescription)
                            try? await self?.auditLogger.logRecoveryAttempt(auditLog)
                        }
                    }
                case let .failure(error):
                    completion(.failure(error))
                    Task { [weak self] in
                        let outcome: PasswordRecoveryOutcome = switch error {
                        case .emailNotFound: .emailNotFound
                        case .network: .networkError
                        case .rateLimitExceeded: .rateLimitExceeded
                        default: .unknown
                        }
                        let auditLog = PasswordRecoveryAuditLog(email: trimmedEmail, ipAddress: ipAddress, userAgent: userAgent, outcome: outcome, errorDetails: error.localizedDescription)
                        try? await self?.auditLogger.logRecoveryAttempt(auditLog)
                    }
                }
            }
        case let .failure(error):
            completion(.failure(error))
            Task { [weak self] in
                guard let self else { return }
                let auditLog = PasswordRecoveryAuditLog(email: trimmedEmail, ipAddress: ipAddress, userAgent: userAgent, outcome: .rateLimitExceeded, errorDetails: error.localizedDescription)
                try? await self.auditLogger.logRecoveryAttempt(auditLog)
            }
        }
    }
}
