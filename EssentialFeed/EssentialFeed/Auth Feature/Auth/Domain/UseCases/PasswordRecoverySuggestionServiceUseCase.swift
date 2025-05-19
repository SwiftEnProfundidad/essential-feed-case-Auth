
import Foundation

public protocol PasswordRecoverySuggestionService {
    func handleFailedAttempt(for email: String, error: Error) async
    func resetAttempts(for email: String) async
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

    public func handleFailedAttempt(for email: String, error: Error) async {
        guard let loginError = error as? LoginError, loginError == .invalidCredentials else { return }
        await failedAttemptsStore.incrementAttempts(for: email)
        let attempts = failedAttemptsStore.getAttempts(for: email)
        if policy.shouldSuggestRecovery(after: attempts) {
            notifier.suggestPasswordRecovery(for: email)
        }
    }

    public func resetAttempts(for email: String) async {
        await failedAttemptsStore.resetAttempts(for: email)
    }
}
