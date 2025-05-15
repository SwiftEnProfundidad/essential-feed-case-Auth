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

private enum StorageKey {
    static let failedAttemptsPrefix = "login_failed_attempts_"
    static let lockoutUntilPrefix = "login_lockout_until_"
}

public final class UserLoginUseCase {
    public struct Config {
        public let maxFailedAttempts: Int
        public let lockoutDuration: TimeInterval
        public static let `default` = Config(maxFailedAttempts: 5, lockoutDuration: 5 * 60)
        public init(maxFailedAttempts: Int, lockoutDuration: TimeInterval) {
            self.maxFailedAttempts = maxFailedAttempts
            self.lockoutDuration = lockoutDuration
        }
    }

    private let api: UserLoginAPI
    private let persistence: LoginPersistence
    private let notifier: LoginEventNotifier
    private let flowHandler: LoginFlowHandler
    private let config: Config

    public init(
        api: UserLoginAPI,
        persistence: LoginPersistence,
        notifier: LoginEventNotifier,
        flowHandler: LoginFlowHandler,
        config: Config = .default
    ) {
        self.api = api
        self.persistence = persistence
        self.notifier = notifier
        self.flowHandler = flowHandler
        self.config = config
    }

    public func login(with credentials: LoginCredentials) async -> Result<LoginResponse, Error> {
        let email = credentials.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validationError = validateCredentials(credentials) {
            let result: Result<LoginResponse, Error> = .failure(validationError)
            await notifyAndHandle(result: result, credentials: credentials)
            return result
        }

        // MARK: - Lockout logic

        let attemptsKey = StorageKey.failedAttemptsPrefix + email
        let lockoutKey = StorageKey.lockoutUntilPrefix + email
        let now = Date()
        let defaults = UserDefaults.standard
        if let until = defaults.object(forKey: lockoutKey) as? Date {
            if now < until {
                let result: Result<LoginResponse, Error> = .failure(LoginError.accountLocked)
                await notifyAndHandle(result: result, credentials: credentials)
                return result
            } else {
                defaults.removeObject(forKey: attemptsKey)
                defaults.removeObject(forKey: lockoutKey)
            }
        }

        let result = await api.login(with: credentials)
        switch result {
        case let .success(response):
            defaults.removeObject(forKey: attemptsKey)
            defaults.removeObject(forKey: lockoutKey)
            let defaultTokenDuration: TimeInterval = 3600
            let expiryDate = Date().addingTimeInterval(defaultTokenDuration)
            let tokenToStore = Token(value: response.token, expiry: expiryDate)
            do {
                try await persistence.saveToken(tokenToStore)
                try? await persistence.saveOfflineCredentials(credentials)
                let result: Result<LoginResponse, Error> = .success(response)
                await notifyAndHandle(result: result, credentials: credentials)
                return result
            } catch {
                let result: Result<LoginResponse, Error> = .failure(LoginError.tokenStorageFailed)
                await notifyAndHandle(result: result, credentials: credentials)
                return result
            }
        case let .failure(error):
            if error == .invalidCredentials {
                let prevAttempts = defaults.integer(forKey: attemptsKey)
                let newAttempts = prevAttempts + 1
                defaults.set(newAttempts, forKey: attemptsKey)
                if newAttempts >= config.maxFailedAttempts {
                    let until = Date().addingTimeInterval(config.lockoutDuration)
                    defaults.set(until, forKey: lockoutKey)

                    let result: Result<LoginResponse, Error> = .failure(LoginError.accountLocked)
                    await notifyAndHandle(result: result, credentials: credentials)
                    return result
                } else {
                    let result: Result<LoginResponse, Error> = .failure(LoginError.invalidCredentials)
                    await notifyAndHandle(result: result, credentials: credentials)
                    return result
                }
            } else {
                let result: Result<LoginResponse, Error> = .failure(error)
                await notifyAndHandle(result: result, credentials: credentials)
                return result
            }
        }
    }

    private func validateCredentials(_ credentials: LoginCredentials) -> LoginError? {
        let email = credentials.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if email.isEmpty || !isValidEmail(email) {
            return .invalidEmailFormat
        }
        let password = credentials.password
        if password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty
            || password.count < 6
        {
            return .invalidPasswordFormat
        }
        return nil
    }

    private func notifyAndHandle(result: Result<LoginResponse, Error>, credentials: LoginCredentials)
        async
    {
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
