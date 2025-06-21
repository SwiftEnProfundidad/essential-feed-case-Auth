import Foundation

public final class DefaultLoginService: LoginService {
    private let validator: LoginCredentialsValidator
    private let securityUseCase: LoginSecurityUseCase
    private let api: UserLoginAPI
    private let persistence: LoginPersistence
    private let config: UserLoginConfiguration

    public init(
        validator: LoginCredentialsValidator,
        securityUseCase: LoginSecurityUseCase,
        api: UserLoginAPI,
        persistence: LoginPersistence,
        config: UserLoginConfiguration
    ) {
        self.validator = validator
        self.securityUseCase = securityUseCase
        self.api = api
        self.persistence = persistence
        self.config = config
    }

    public func execute(credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
        if let validationError = validator.validate(credentials) {
            return .failure(validationError)
        }

        if let securityError = await checkSecurity(credentials) {
            return .failure(securityError)
        }

        let authResult = await api.login(with: credentials)
        switch authResult {
        case let .success(response):
            return await handleSuccess(response, credentials)
        case let .failure(error):
            return await handleAuthFailure(error, credentials)
        }
    }

    private func checkSecurity(_ credentials: LoginCredentials) async -> LoginError? {
        let email = validator.normalizeEmail(credentials.email)
        if await securityUseCase.isAccountLocked(username: email) {
            let remaining = securityUseCase.getRemainingBlockTime(username: email)
            return .accountLocked(remainingTime: Int(remaining ?? 0))
        }
        return nil
    }

    private func handleSuccess(_ response: LoginResponse, _ credentials: LoginCredentials) async
        -> Result<LoginResponse, LoginError>
    {
        let email = validator.normalizeEmail(credentials.email)
        await securityUseCase.resetAttempts(username: email)

        do {
            try await persistence.saveLoginData(response, credentials)
            return .success(response)
        } catch {
            return .failure(.tokenStorageFailed)
        }
    }

    private func handleAuthFailure(_ error: LoginError, _ credentials: LoginCredentials) async
        -> Result<LoginResponse, LoginError>
    {
        guard error == .invalidCredentials else {
            return .failure(error)
        }

        let email = validator.normalizeEmail(credentials.email)
        await securityUseCase.handleFailedLogin(username: email)

        if let securityError = await checkSecurity(credentials) {
            return .failure(securityError)
        }

        return .failure(.invalidCredentials)
    }
}
