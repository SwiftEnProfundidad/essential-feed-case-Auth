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
        public static let defaultTokenDuration: TimeInterval = 3600
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
        guard let validationError = validateCredentials(credentials) else {
            guard let lockoutError = checkLockout(for: email) else {
                let result = await api.login(with: credentials)
                switch result {
                case let .success(response):
                    return await handleSuccess(response, credentials)
                case let .failure(error):
                    return await handleLoginFailure(error, credentials, email)
                }
            }
            return await handleFailure(.failure(lockoutError), credentials)
        }
        return await handleFailure(.failure(validationError), credentials)
    }

    private func checkLockout(for email: String) -> LoginError? {
        let attemptsKey = StorageKey.failedAttemptsPrefix + email
        let lockoutKey = StorageKey.lockoutUntilPrefix + email
        let now = Date()
        let defaults = UserDefaults.standard
        if let until = defaults.object(forKey: lockoutKey) as? Date, now < until {
            return .accountLocked
        } else if defaults.object(forKey: lockoutKey) != nil {
            defaults.removeObject(forKey: attemptsKey)
            defaults.removeObject(forKey: lockoutKey)
        }
        return nil
    }

    private func handleSuccess(_ response: LoginResponse, _ credentials: LoginCredentials) async -> Result<LoginResponse, Error> {
        clearLockout(for: credentials.email)
        let expiryDate = Date().addingTimeInterval(Config.defaultTokenDuration)
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
    }

    private func handleLoginFailure(_ error: LoginError, _ credentials: LoginCredentials, _ email: String) async -> Result<LoginResponse, Error> {
        let attemptsKey = StorageKey.failedAttemptsPrefix + email
        let lockoutKey = StorageKey.lockoutUntilPrefix + email
        let defaults = UserDefaults.standard
        guard error == .invalidCredentials else {
            return await handleFailure(.failure(error), credentials)
        }
        let prevAttempts = defaults.integer(forKey: attemptsKey)
        let newAttempts = prevAttempts + 1
        defaults.set(newAttempts, forKey: attemptsKey)
        guard newAttempts <= config.maxFailedAttempts else {
            return await handleFailure(.failure(LoginError.accountLocked), credentials)
        }
        guard newAttempts != config.maxFailedAttempts else {
            let until = Date().addingTimeInterval(config.lockoutDuration)
            defaults.set(until, forKey: lockoutKey)
            return await handleFailure(.failure(LoginError.invalidCredentials), credentials)
        }
        return await handleFailure(.failure(LoginError.invalidCredentials), credentials)
    }

    private var defaults: UserDefaults { UserDefaults.standard }
    private func attemptsKey(for email: String) -> String {
        StorageKey.failedAttemptsPrefix + email
    }

    private func lockoutKey(for email: String) -> String {
        StorageKey.lockoutUntilPrefix + email
    }

    private func handleFailure(_ result: Result<LoginResponse, Error>, _ credentials: LoginCredentials) async -> Result<LoginResponse, Error> {
        await notifyAndHandle(result: result, credentials: credentials)
        return result
    }

    private func clearLockout(for email: String) {
        defaults.removeObject(forKey: attemptsKey(for: email))
        defaults.removeObject(forKey: lockoutKey(for: email))
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

    private func notifyAndHandle(result: Result<LoginResponse, Error>, credentials: LoginCredentials) async {
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
