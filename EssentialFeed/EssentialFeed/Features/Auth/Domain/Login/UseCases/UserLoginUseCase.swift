
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
    private let api: UserLoginAPI
    private let persistence: LoginPersistence
    private let notifier: LoginEventNotifier
    private let flowHandler: LoginFlowHandler?

    public init(
        api: UserLoginAPI,
        persistence: LoginPersistence,
        notifier: LoginEventNotifier,
        flowHandler: LoginFlowHandler? = nil
    ) {
        self.api = api
        self.persistence = persistence
        self.notifier = notifier
        self.flowHandler = flowHandler
    }

    public func login(with credentials: LoginCredentials) async -> Result<LoginResponse, Error> {
        let email = credentials.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if email.isEmpty {
            notifier.notifyFailure(error: LoginError.invalidEmailFormat)
            flowHandler?.handlePostLogin(result: .failure(LoginError.invalidEmailFormat), credentials: credentials)
            return .failure(LoginError.invalidEmailFormat)
        }
        guard isValidEmail(email) else {
            notifier.notifyFailure(error: LoginError.invalidEmailFormat)
            flowHandler?.handlePostLogin(result: .failure(LoginError.invalidEmailFormat), credentials: credentials)
            return .failure(LoginError.invalidEmailFormat)
        }

        let password = credentials.password
        if password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty {
            notifier.notifyFailure(error: LoginError.invalidPasswordFormat)
            flowHandler?.handlePostLogin(result: .failure(LoginError.invalidPasswordFormat), credentials: credentials)
            return .failure(LoginError.invalidPasswordFormat)
        }
        if password.isEmpty {
            notifier.notifyFailure(error: LoginError.invalidPasswordFormat)
            flowHandler?.handlePostLogin(result: .failure(LoginError.invalidPasswordFormat), credentials: credentials)
            return .failure(LoginError.invalidPasswordFormat)
        }
        if password.count < 6 {
            notifier.notifyFailure(error: LoginError.invalidPasswordFormat)
            flowHandler?.handlePostLogin(result: .failure(LoginError.invalidPasswordFormat), credentials: credentials)
            return .failure(LoginError.invalidPasswordFormat)
        }

        let result = await api.login(with: credentials)
        switch result {
        case let .success(response):
            let defaultTokenDuration: TimeInterval = 3600
            let expiryDate = Date().addingTimeInterval(defaultTokenDuration)
            let tokenToStore = Token(value: response.token, expiry: expiryDate)
            do {
                try await persistence.saveToken(tokenToStore)
                try? await persistence.saveOfflineCredentials(credentials)
                notifier.notifySuccess(response: response)
                let finalResult: Result<LoginResponse, Error> = .success(response)
                flowHandler?.handlePostLogin(result: finalResult, credentials: credentials)
                return finalResult
            } catch {
                notifier.notifyFailure(error: LoginError.tokenStorageFailed)
                let finalResult: Result<LoginResponse, Error> = .failure(LoginError.tokenStorageFailed)
                flowHandler?.handlePostLogin(result: finalResult, credentials: credentials)
                return finalResult
            }
        case let .failure(error):
            notifier.notifyFailure(error: error)
            let finalResult: Result<LoginResponse, Error> = .failure(error)
            flowHandler?.handlePostLogin(result: finalResult, credentials: credentials)
            return finalResult
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}
