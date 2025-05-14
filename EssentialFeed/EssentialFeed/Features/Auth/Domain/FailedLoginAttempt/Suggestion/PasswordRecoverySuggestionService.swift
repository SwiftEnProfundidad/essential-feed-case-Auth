
import Foundation

public protocol PasswordRecoverySuggestionService {
    func handleFailedAttempt(for email: String, error: Error)
    func resetAttempts(for email: String)
}

public final class DefaultPasswordRecoverySuggestionService: PasswordRecoverySuggestionService {
    private let failedAttemptsStore: FailedLoginAttemptsStore
    private let policy: PasswordRecoveryPolicy
    private let notifier: PasswordRecoverySuggestionNotifier

    public init(
        failedAttemptsStore: FailedLoginAttemptsStore,
        policy: PasswordRecoveryPolicy,
        notifier: PasswordRecoverySuggestionNotifier
    ) {
        self.failedAttemptsStore = failedAttemptsStore
        self.policy = policy
        self.notifier = notifier
    }

    public func handleFailedAttempt(for email: String, error: Error) {
        guard let loginError = error as? LoginError, loginError == .invalidCredentials else { return }
        failedAttemptsStore.incrementAttempts(for: email)
        let attempts = failedAttemptsStore.getAttempts(for: email)
        if policy.shouldSuggestRecovery(after: attempts) {
            notifier.suggestPasswordRecovery(for: email)
        }
    }

    public func resetAttempts(for email: String) {
        failedAttemptsStore.resetAttempts(for: email)
    }
}
