
import Foundation

public protocol PasswordRecoveryPolicy {
    func shouldSuggestRecovery(after attempts: Int) -> Bool
}

public final class MaxAttemptsPasswordRecoveryPolicy: PasswordRecoveryPolicy {
    private let maxAttempts: Int
    public init(maxAttempts: Int) { self.maxAttempts = maxAttempts }
    public func shouldSuggestRecovery(after attempts: Int) -> Bool {
        attempts == maxAttempts
    }
}
