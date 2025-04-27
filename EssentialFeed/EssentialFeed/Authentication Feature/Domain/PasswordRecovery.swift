import Foundation

public final class UserPasswordRecoveryUseCase {
    private let api: PasswordRecoveryAPI

    public init(api: PasswordRecoveryAPI) {
        self.api = api
    }

    public func recoverPassword(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        // Validación de formato básica (puedes mejorarla según guidelines)
        guard !trimmedEmail.isEmpty, trimmedEmail.contains("@") else {
            completion(.failure(.invalidEmailFormat))
            return
        }
        api.recover(email: trimmedEmail, completion: completion)
    }
}
