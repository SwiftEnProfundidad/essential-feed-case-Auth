import Foundation

public protocol PasswordResetUseCase {
    func resetPassword(token: String, newPassword: String, completion: @escaping (Result<Void, PasswordResetTokenError>) -> Void)
}

public protocol PasswordUpdater {
    func updatePassword(for email: String, newPassword: String, completion: @escaping (Result<Void, Error>) -> Void)
}

public final class DefaultPasswordResetUseCase: PasswordResetUseCase {
    private let tokenStore: PasswordResetTokenStore
    private let passwordUpdater: PasswordUpdater
    private let passwordValidator: PasswordValidator

    public init(tokenStore: PasswordResetTokenStore, passwordUpdater: PasswordUpdater, passwordValidator: PasswordValidator) {
        self.tokenStore = tokenStore
        self.passwordUpdater = passwordUpdater
        self.passwordValidator = passwordValidator
    }

    public func resetPassword(token: String, newPassword: String, completion: @escaping (Result<Void, PasswordResetTokenError>) -> Void) {
        let validationResult = passwordValidator.validate(password: newPassword)
        if case let .failure(error) = validationResult {
            completion(.failure(.validationFailed(error)))
            return
        }

        guard let resetToken = tokenStore.getToken(token) else {
            completion(.failure(.tokenNotFound))
            return
        }

        if resetToken.isExpired {
            completion(.failure(.tokenExpired))
            return
        }

        if resetToken.isUsed {
            completion(.failure(.tokenAlreadyUsed))
            return
        }

        passwordUpdater.updatePassword(for: resetToken.email, newPassword: newPassword) { [weak self] result in
            switch result {
            case .success:
                do {
                    try self?.tokenStore.markTokenAsUsed(token)
                    completion(.success(()))
                } catch {
                    completion(.failure(.storageError))
                }
            case .failure:
                completion(.failure(.storageError))
            }
        }
    }
}
