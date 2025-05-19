import Foundation

public final class DefaultLoginFlowHandler: LoginFlowHandler {
    private let recoverySuggestionService: PasswordRecoverySuggestionService?

    public init(recoverySuggestionService: PasswordRecoverySuggestionService? = nil) {
        self.recoverySuggestionService = recoverySuggestionService
    }

    public func handlePostLogin(result: Result<LoginResponse, LoginError>, credentials: LoginCredentials) async {
        switch result {
        case .success:
            await recoverySuggestionService?.resetAttempts(for: credentials.email)
        case let .failure(error):
            await recoverySuggestionService?.handleFailedAttempt(for: credentials.email, error: error)
        }
    }
}
