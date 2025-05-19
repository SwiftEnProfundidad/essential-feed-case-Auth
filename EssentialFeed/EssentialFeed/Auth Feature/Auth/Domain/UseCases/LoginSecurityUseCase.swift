import Foundation

public final class LoginSecurityUseCase {
    private let store: FailedLoginAttemptsStore
    private let maxAttempts: Int
    private let blockDuration: TimeInterval
    private let timeProvider: () -> Date

    public init(
        store: FailedLoginAttemptsStore = InMemoryFailedLoginAttemptsStore(),
        maxAttempts: Int = 5,
        blockDuration: TimeInterval = 300,
        timeProvider: @escaping () -> Date = { Date() }
    ) {
        self.store = store
        self.maxAttempts = maxAttempts
        self.blockDuration = blockDuration
        self.timeProvider = timeProvider
    }
}

// MARK: - LoginLockStatusProviderProtocol

extension LoginSecurityUseCase: LoginLockStatusProviderProtocol {
    public func isAccountLocked(username: String) -> Bool {
        let attempts = store.getAttempts(for: username)
        guard attempts >= maxAttempts,
              let lastAttempt = store.lastAttemptTime(for: username)
        else {
            return false
        }
        return timeProvider().timeIntervalSince(lastAttempt) < blockDuration
    }

    public func getRemainingBlockTime(username: String) -> TimeInterval? {
        guard let lastAttempt = store.lastAttemptTime(for: username) else { return nil }
        let elapsed = timeProvider().timeIntervalSince(lastAttempt)
        return max(0, blockDuration - elapsed)
    }
}

// MARK: - FailedLoginHandlerProtocol

extension LoginSecurityUseCase: FailedLoginHandlerProtocol {
    public func handleFailedLogin(username: String) async {
        await store.incrementAttempts(for: username)
    }

    public func resetAttempts(username: String) async {
        await store.resetAttempts(for: username)
    }
}
