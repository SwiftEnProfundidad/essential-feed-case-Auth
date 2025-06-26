import Foundation

public final class DefaultLoginSecurityServiceUseCase {
    private let store: FailedLoginAttemptsStore
    private let configuration: LoginSecurityConfiguration
    private let timeProvider: () -> Date

    public init(
        store: FailedLoginAttemptsStore,
        configuration: LoginSecurityConfiguration = .default,
        timeProvider: @escaping () -> Date = { Date() }
    ) {
        self.store = store
        self.configuration = configuration
        self.timeProvider = timeProvider
    }
}

// MARK: - LoginLockStatusProvider

extension DefaultLoginSecurityServiceUseCase: LoginLockStatusProviderProtocol {
    public func isAccountLocked(username: String) async -> Bool {
        let attempts = store.getAttempts(for: username)
        guard attempts >= configuration.maxAttempts,
              let lastAttempt = store.lastAttemptTime(for: username)
        else {
            return false
        }

        let timeSinceLastAttempt = timeProvider().timeIntervalSince(lastAttempt)
        if timeSinceLastAttempt >= configuration.blockDuration {
            await store.resetAttempts(for: username)
            return false
        }
        return true
    }

    public func getRemainingBlockTime(username: String) -> TimeInterval? {
        guard let lastAttempt = store.lastAttemptTime(for: username) else { return nil }
        let elapsed = timeProvider().timeIntervalSince(lastAttempt)
        return max(0, configuration.blockDuration - elapsed)
    }
}

// MARK: - LoginSecurityHandler

extension DefaultLoginSecurityServiceUseCase: LoginSecurityHandlerProtocol {
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
