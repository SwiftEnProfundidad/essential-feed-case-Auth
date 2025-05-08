import Foundation

public protocol LoginSuccessObserver {
    func didLoginSuccessfully(response: LoginResponse)
}

public protocol LoginFailureObserver {
    func didFailLogin(error: LoginError)
}

public final class UserLoginUseCase {
    private let api: UserLoginAPI
    private let tokenStorage: TokenStorage
    private let offlineStore: OfflineLoginStore
    private let successObserver: LoginSuccessObserver
    private let failureObserver: LoginFailureObserver

    public init(
        api: UserLoginAPI,
        tokenStorage: TokenStorage,
        offlineStore: OfflineLoginStore,
        successObserver: LoginSuccessObserver,
        failureObserver: LoginFailureObserver
    ) {
        self.api = api
        self.tokenStorage = tokenStorage
        self.offlineStore = offlineStore
        self.successObserver = successObserver
        self.failureObserver = failureObserver
    }

    public func login(with credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
        // VALIDACIÓN DE EMAIL
        let email = credentials.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if email.isEmpty {
					failureObserver.didFailLogin(error: .invalidEmailFormat)
            return .failure(.invalidEmailFormat)
        }
        guard isValidEmail(email) else {
					failureObserver.didFailLogin(error: .invalidEmailFormat)
            return .failure(.invalidEmailFormat)
        }

        // VALIDACIÓN DE CONTRASEÑA
        let password = credentials.password

        if password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty {
					failureObserver.didFailLogin(error: .invalidPasswordFormat)
            return .failure(.invalidPasswordFormat)
        }

        if password.isEmpty {
					failureObserver.didFailLogin(error: .invalidPasswordFormat)
            return .failure(.invalidPasswordFormat)
        }

        if password.count < 6 {
					failureObserver.didFailLogin(error: .invalidPasswordFormat)
            return .failure(.invalidPasswordFormat)
        }

        let result = await api.login(with: credentials)

        switch result {
        case .success(let response):
            let defaultTokenDuration: TimeInterval = 3600
            let expiryDate = Date().addingTimeInterval(defaultTokenDuration)

            let tokenToStore = Token(value: response.token, expiry: expiryDate)

            do {
                try await tokenStorage.save(tokenToStore)
                successObserver.didLoginSuccessfully(response: response)
                return .success(response)
            } catch {
                failureObserver.didFailLogin(error: .tokenStorageFailed)
                return .failure(.tokenStorageFailed)
            }

        case .failure(let error):
            if error == .noConnectivity {
                do {
                    try await offlineStore.save(credentials: credentials)
                    failureObserver.didFailLogin(error: .noConnectivity)
                    return .failure(.noConnectivity)
                } catch {
                    let loginOfflineError = LoginError.offlineStoreFailed
                    failureObserver.didFailLogin(error: loginOfflineError)
                    return .failure(loginOfflineError)
                }
            } else {
                failureObserver.didFailLogin(error: error)
                return .failure(error)
            }
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}
