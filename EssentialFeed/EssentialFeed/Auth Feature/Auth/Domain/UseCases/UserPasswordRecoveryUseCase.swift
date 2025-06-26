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
            Task { [weak self] in
                if let self {
                    let auditLog = PasswordRecoveryAuditLog(email: trimmedEmail, ipAddress: ipAddress, userAgent: userAgent, outcome: .invalidEmailFormat)
                    try? await self.auditLogger.logRecoveryAttempt(auditLog)
                }
                completion(.failure(.invalidEmailFormat))
            }
            return
        }

        switch rateLimiter.isAllowed(for: trimmedEmail) {
        case .success:
            rateLimiter.recordAttempt(for: trimmedEmail, ipAddress: ipAddress)

            api.recover(email: trimmedEmail) { [weak self] result in
                guard let self else { return }

                Task { [weak self] in
                    guard let self else { return }

                    switch result {
                    case .success:
                        do {
                            let resetToken = try self.tokenManager.generateResetToken(for: trimmedEmail)
                            let response = PasswordRecoveryResponse(message: "Password reset link sent to your email", resetToken: resetToken.token)

                            let auditLog = PasswordRecoveryAuditLog(email: trimmedEmail, ipAddress: ipAddress, userAgent: userAgent, outcome: .success)
                            try? await self.auditLogger.logRecoveryAttempt(auditLog)

                            completion(.success(response))
                        } catch {
                            let auditLog = PasswordRecoveryAuditLog(email: trimmedEmail, ipAddress: ipAddress, userAgent: userAgent, outcome: .tokenGenerationFailed, errorDetails: error.localizedDescription)
                            try? await self.auditLogger.logRecoveryAttempt(auditLog)

                            completion(.failure(.tokenGenerationFailed))
                        }
                    case let .failure(error):
                        let outcome: PasswordRecoveryOutcome = switch error {
                        case .emailNotFound:
                            .emailNotFound
                        case .network:
                            .networkError
                        case .rateLimitExceeded:
                            .rateLimitExceeded
                        default:
                            .unknown
                        }

                        let auditLog = PasswordRecoveryAuditLog(email: trimmedEmail, ipAddress: ipAddress, userAgent: userAgent, outcome: outcome, errorDetails: error.localizedDescription)
                        try? await self.auditLogger.logRecoveryAttempt(auditLog)

                        completion(.failure(error))
                    }
                }
            }
        case let .failure(error):
            Task { [weak self] in
                guard let self else { return }
                let auditLog = PasswordRecoveryAuditLog(email: trimmedEmail, ipAddress: ipAddress, userAgent: userAgent, outcome: .rateLimitExceeded, errorDetails: error.localizedDescription)
                try? await self.auditLogger.logRecoveryAttempt(auditLog)
                completion(.failure(error))
            }
        }
    }
}
