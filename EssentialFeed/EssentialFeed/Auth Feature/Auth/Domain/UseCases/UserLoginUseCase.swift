import Foundation

public protocol LoginSuccessObserver {
    func didLoginSuccessfully(response: LoginResponse)
}

public protocol LoginFailureObserver {
    func didFailLogin(error: Error)
}

public protocol PasswordRecoverySuggestionObserver {
    func suggestPasswordRecovery(for email: String)
}

public final class UserLoginUseCase {
    private let loginService: LoginService

    public init(loginService: LoginService) {
        self.loginService = loginService
    }

    public func login(with credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
        await loginService.execute(credentials: credentials)
    }
}
