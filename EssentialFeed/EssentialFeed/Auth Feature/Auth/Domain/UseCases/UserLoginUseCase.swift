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

public struct UserLoginConfiguration {
    public let maxFailedAttempts: Int
    public let lockoutDuration: TimeInterval
    public let tokenDuration: TimeInterval
    public init(maxFailedAttempts: Int, lockoutDuration: TimeInterval, tokenDuration: TimeInterval) {
        self.maxFailedAttempts = maxFailedAttempts
        self.lockoutDuration = lockoutDuration
        self.tokenDuration = tokenDuration
    }
}

public final class UserLoginUseCase {
    private let api: UserLoginAPI
    private let persistence: LoginPersistence
    private let notifier: LoginEventNotifier
    private let flowHandler: LoginFlowHandler
    private let config: UserLoginConfiguration
    private let lockStatusProvider: LoginLockStatusProviderProtocol
    private let failedLoginHandler: FailedLoginHandlerProtocol

    public init(
        api: UserLoginAPI,
        persistence: LoginPersistence,
        notifier: LoginEventNotifier,
        flowHandler: LoginFlowHandler,
        lockStatusProvider: LoginLockStatusProviderProtocol,
        failedLoginHandler: FailedLoginHandlerProtocol,
        config: UserLoginConfiguration
    ) {
        self.api = api
        self.persistence = persistence
        self.notifier = notifier
        self.flowHandler = flowHandler
        self.lockStatusProvider = lockStatusProvider
        self.failedLoginHandler = failedLoginHandler
        self.config = config
    }

    public func login(with credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
        let email = credentials.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let validationError = validateCredentials(credentials) else {
            let isLocked = await lockStatusProvider.isAccountLocked(username: email)
            if isLocked {
                let remaining = lockStatusProvider.getRemainingBlockTime(username: email)
                let lockoutError = LoginError.accountLocked(remainingTime: Int(remaining ?? 0))
                return await handleFailure(.failure(lockoutError), credentials)
            }
            let result = await api.login(with: credentials)
            switch result {
            case let .success(response):
                return await handleSuccess(response, credentials)
            case let .failure(error):
                return await handleLoginFailure(error, credentials, email)
            }
        }
        return await handleFailure(.failure(validationError), credentials)
    }

    private func handleSuccess(_ response: LoginResponse, _ credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
        await clearLockout(for: credentials.email)
        let expiryDate = Date().addingTimeInterval(config.tokenDuration)
        let tokenToStore = Token(
            accessToken: response.token,
            expiry: expiryDate,
            refreshToken: nil
        )
        do {
            try await persistence.saveToken(tokenToStore)
            try? await persistence.saveOfflineCredentials(credentials)
            let result: Result<LoginResponse, LoginError> = .success(response)
            await notifyAndHandle(result: result, credentials: credentials)
            return result
        } catch {
            let result: Result<LoginResponse, LoginError> = .failure(LoginError.tokenStorageFailed)
            await notifyAndHandle(result: result, credentials: credentials)
            return result
        }
    }

    private func handleLoginFailure(_ error: LoginError, _ credentials: LoginCredentials, _ email: String) async -> Result<LoginResponse, LoginError> {
        guard error == .invalidCredentials else {
            return await handleFailure(.failure(error), credentials)
        }
        await failedLoginHandler.handleFailedLogin(username: email)
        let isLocked = await lockStatusProvider.isAccountLocked(username: email)
        if isLocked {
            let remaining = lockStatusProvider.getRemainingBlockTime(username: email)
            let lockoutError = LoginError.accountLocked(remainingTime: Int(remaining ?? 0))
            return await handleFailure(.failure(lockoutError), credentials)
        }
        return await handleFailure(.failure(LoginError.invalidCredentials), credentials)
    }

    private func handleFailure(_ result: Result<LoginResponse, LoginError>, _ credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
        await notifyAndHandle(result: result, credentials: credentials)
        return result
    }

    private func clearLockout(for email: String) async {
        await failedLoginHandler.resetAttempts(username: email)
    }

    private func validateCredentials(_ credentials: LoginCredentials) -> LoginError? {
        let email = credentials.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if email.isEmpty || !isValidEmail(email) {
            return .invalidEmailFormat
        }
        let password = credentials.password
        if password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || password.count < 6 {
            return .invalidPasswordFormat
        }
        return nil
    }

    private func notifyAndHandle(result: Result<LoginResponse, LoginError>, credentials: LoginCredentials) async {
        switch result {
        case let .success(response):
            notifier.notifySuccess(response: response)
        case let .failure(error):
            notifier.notifyFailure(error: error)
        }
        await flowHandler.handlePostLogin(result: result, credentials: credentials)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}
