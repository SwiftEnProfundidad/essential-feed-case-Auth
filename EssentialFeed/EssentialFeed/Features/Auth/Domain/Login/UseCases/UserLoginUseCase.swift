
import Foundation

public protocol LoginSuccessObserver {
    func didLoginSuccessfully(response: LoginResponse)
}

public protocol LoginFailureObserver {
    func didFailLogin(error: Error)
}

public final class UserLoginUseCase {
    private let api: UserLoginAPI
    private let tokenStorage: TokenStorage
    private let offlineStore: OfflineLoginStore
    private let failedAttemptsStore: FailedLoginAttemptsStore
    private let successObserver: LoginSuccessObserver
    private let failureObserver: LoginFailureObserver

    private let maxFailedAttempts = 5
    private let lockoutDuration: TimeInterval = 300

    public init(
        api: UserLoginAPI,
        tokenStorage: TokenStorage,
        offlineStore: OfflineLoginStore,
        failedAttemptsStore: FailedLoginAttemptsStore,
        successObserver: LoginSuccessObserver,
        failureObserver: LoginFailureObserver
    ) {
        self.api = api
        self.tokenStorage = tokenStorage
        self.offlineStore = offlineStore
        self.failedAttemptsStore = failedAttemptsStore
        self.successObserver = successObserver
        self.failureObserver = failureObserver
    }

    public func login(with credentials: LoginCredentials) async -> Result<LoginResponse, Error> {
        let email = credentials.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if email.isEmpty {
            failureObserver.didFailLogin(error: LoginError.invalidEmailFormat)
            return .failure(LoginError.invalidEmailFormat)
        }
        guard isValidEmail(email) else {
            failureObserver.didFailLogin(error: LoginError.invalidEmailFormat)
            return .failure(LoginError.invalidEmailFormat)
        }

        if let lockoutInfo = getAccountLockoutInfo(email) {
            let accountLockedError = AccountLockedError(username: email, remainingLockTime: lockoutInfo.remainingTime)
            failureObserver.didFailLogin(error: accountLockedError)
            return .failure(accountLockedError)
        }

        let password = credentials.password

        if password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty {
            failureObserver.didFailLogin(error: LoginError.invalidPasswordFormat)
            return .failure(LoginError.invalidPasswordFormat)
        }

        if password.isEmpty {
            failureObserver.didFailLogin(error: LoginError.invalidPasswordFormat)
            return .failure(LoginError.invalidPasswordFormat)
        }

        if password.count < 6 {
            failureObserver.didFailLogin(error: LoginError.invalidPasswordFormat)
            return .failure(LoginError.invalidPasswordFormat)
        }

        let result = await api.login(with: credentials)

        switch result {
        case let .success(response):
            let defaultTokenDuration: TimeInterval = 3600
            let expiryDate = Date().addingTimeInterval(defaultTokenDuration)

            let tokenToStore = Token(value: response.token, expiry: expiryDate)

            do {
                try await tokenStorage.save(tokenToStore)
                failedAttemptsStore.resetAttempts(for: credentials.email)
                successObserver.didLoginSuccessfully(response: response)
                return .success(response)
            } catch {
                failureObserver.didFailLogin(error: LoginError.tokenStorageFailed)
                return .failure(LoginError.tokenStorageFailed)
            }
        case let .failure(error):
            if error == .noConnectivity {
                do {
                    try await offlineStore.save(credentials: credentials)
                    failureObserver.didFailLogin(error: LoginError.noConnectivity)
                    failedAttemptsStore.incrementAttempts(for: credentials.email)
                    return .failure(LoginError.noConnectivity)
                } catch {
                    let loginOfflineError = LoginError.offlineStoreFailed
                    failureObserver.didFailLogin(error: loginOfflineError)
                    failedAttemptsStore.incrementAttempts(for: credentials.email)
                    return .failure(loginOfflineError)
                }
            } else {
                if error != .invalidEmailFormat, error != .invalidPasswordFormat {
                    failedAttemptsStore.incrementAttempts(for: credentials.email)
                }
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

    private struct LockoutInfo {
        let isLocked: Bool
        let remainingTime: TimeInterval
    }

    private func getAccountLockoutInfo(_ username: String) -> LockoutInfo? {
        let attempts = failedAttemptsStore.getAttempts(for: username)

        if attempts >= maxFailedAttempts, let lastAttemptTime = failedAttemptsStore.lastAttemptTime(for: username) {
            let timeSinceLastAttempt = Date().timeIntervalSince(lastAttemptTime)
            let remainingLockTime = max(0, lockoutDuration - timeSinceLastAttempt)

            if remainingLockTime > 0 {
                return LockoutInfo(isLocked: true, remainingTime: remainingLockTime)
            }
        }

        return nil
    }
}
