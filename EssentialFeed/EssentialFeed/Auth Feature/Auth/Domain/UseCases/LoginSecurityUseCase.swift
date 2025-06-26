import Foundation

public final class LoginSecurityUseCase {
    private let store: FailedLoginAttemptsStore
    private let configuration: LoginSecurityConfiguration
    private let timeProvider: () -> Date

    public init(
        store: FailedLoginAttemptsStore = InMemoryFailedLoginAttemptsStore(),
        configuration: LoginSecurityConfiguration = .default,
        timeProvider: @escaping () -> Date = { Date() }
    ) {
        self.store = store
        self.configuration = configuration
        self.timeProvider = timeProvider
    }
}

// MARK: - LoginLockStatusProviderProtocol

extension LoginSecurityUseCase: LoginLockStatusProviderProtocol {
    public func isAccountLocked(username: String) async -> Bool {
        let attempts = store.getAttempts(for: username)
        guard attempts >= configuration.maxAttempts,
              let lastAttempt = store.lastAttemptTime(for: username)
        else {
            return false
        }

        let timeSinceLastAttempt = timeProvider().timeIntervalSince(lastAttempt)
        if timeSinceLastAttempt >= configuration.blockDuration {
            await resetAttempts(username: username)
            return false
        }
        return true
    }

    public func getRemainingBlockTime(username: String) -> TimeInterval? {
        guard let lastAttempt = store.lastAttemptTime(for: username) else { return nil }
        let elapsed = timeProvider().timeIntervalSince(lastAttempt)
        let remaining = configuration.blockDuration - elapsed
        return remaining > 0 ? remaining : nil
    }
}

// MARK: - LoginSecurityHandler

extension LoginSecurityUseCase: LoginSecurityHandlerProtocol {
    public func handleFailedLogin(username: String) async {
        await store.incrementAttempts(for: username)
    }

    public func resetAttempts(username: String) async {
        await store.resetAttempts(for: username)
    }

    public func handleSuccessfulCaptcha(for username: String) async {
        await resetAttempts(username: username)
    }

    public func getFailedAttempts(username: String) -> Int {
        store.getAttempts(for: username)
    }
}
