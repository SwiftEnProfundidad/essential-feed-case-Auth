import Foundation

public final class InMemoryPasswordRecoveryRateLimitStore: PasswordRecoveryRateLimitStore {
    private var attempts: [String: [PasswordRecoveryAttempt]] = [:]
    private let queue = DispatchQueue(label: "InMemoryPasswordRecoveryRateLimitStore", attributes: .concurrent)

    public init() {}

    public func getAttempts(for email: String) -> [PasswordRecoveryAttempt] {
        queue.sync {
            attempts[email] ?? []
        }
    }

    public func recordAttempt(_ attempt: PasswordRecoveryAttempt) {
        queue.async(flags: .barrier) {
            self.attempts[attempt.email, default: []].append(attempt)
        }
    }

    public func clearAttempts(for email: String) {
        queue.async(flags: .barrier) {
            self.attempts[email] = nil
        }
    }
}
