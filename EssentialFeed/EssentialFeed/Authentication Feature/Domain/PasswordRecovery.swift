import Foundation

public protocol UserPasswordRecoveryUseCaseProtocol {
    func recoverPassword(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void)
}

public final class RemoteUserPasswordRecoveryUseCase: UserPasswordRecoveryUseCase {
    private let api: PasswordRecoveryAPI

    public init(api: PasswordRecoveryAPI) {
        self.api = api
    }

    public func recoverPassword(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        guard emailPredicate.evaluate(with: trimmedEmail) else {
            completion(.failure(.invalidEmailFormat))
            return
        }
        api.recover(email: trimmedEmail, completion: completion)
    }
}
