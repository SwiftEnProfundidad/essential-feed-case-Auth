import Foundation

public protocol UserPasswordRecoveryUseCase {
    func recoverPassword(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void)
}

public final class RemoteUserPasswordRecoveryUseCase: UserPasswordRecoveryUseCase {
    private let api: PasswordRecoveryAPI
    private let rateLimiter: PasswordRecoveryRateLimiter

    public init(api: PasswordRecoveryAPI, rateLimiter: PasswordRecoveryRateLimiter) {
        self.api = api
        self.rateLimiter = rateLimiter
    }

    public func recoverPassword(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        guard emailPredicate.evaluate(with: trimmedEmail) else {
            completion(.failure(.invalidEmailFormat))
            return
        }

        switch rateLimiter.isAllowed(for: trimmedEmail) {
        case .success:
            rateLimiter.recordAttempt(for: trimmedEmail, ipAddress: nil)
            api.recover(email: trimmedEmail, completion: completion)
        case let .failure(error):
            completion(.failure(error))
        }
    }
}
