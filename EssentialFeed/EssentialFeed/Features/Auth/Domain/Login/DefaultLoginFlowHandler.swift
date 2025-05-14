import Foundation

public final class DefaultLoginFlowHandler: LoginFlowHandler {
    private let recoverySuggestionService: PasswordRecoverySuggestionService?

    public init(recoverySuggestionService: PasswordRecoverySuggestionService? = nil) {
        self.recoverySuggestionService = recoverySuggestionService
    }

    public func handlePostLogin(result: Result<LoginResponse, Error>, credentials: LoginCredentials) {
        switch result {
        case .success:
            recoverySuggestionService?.resetAttempts(for: credentials.email)
        case let .failure(error):
            recoverySuggestionService?.handleFailedAttempt(for: credentials.email, error: error)
        }
    }
}
