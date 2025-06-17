import Foundation

public final class DefaultPasswordRecoveryRateLimiter: PasswordRecoveryRateLimiter {
    private let attemptReader: PasswordRecoveryAttemptReader
    private let attemptWriter: PasswordRecoveryAttemptWriter
    private let maxAttempts: Int
    private let timeWindowMinutes: Int

    public init(
        attemptReader: PasswordRecoveryAttemptReader,
        attemptWriter: PasswordRecoveryAttemptWriter,
        maxAttempts: Int = 3,
        timeWindowMinutes: Int = 15
    ) {
        self.attemptReader = attemptReader
        self.attemptWriter = attemptWriter
        self.maxAttempts = maxAttempts
        self.timeWindowMinutes = timeWindowMinutes
    }

    public convenience init(store: PasswordRecoveryRateLimitStore, maxAttempts: Int = 3, timeWindowMinutes: Int = 15) {
        self.init(attemptReader: store, attemptWriter: store, maxAttempts: maxAttempts, timeWindowMinutes: timeWindowMinutes)
    }

    public func isAllowed(for email: String) -> Result<Void, PasswordRecoveryError> {
        let attempts = attemptReader.getAttempts(for: email)
        let cutoffTime = Date().addingTimeInterval(-TimeInterval(timeWindowMinutes * 60))
        let recentAttempts = attempts.filter { $0.timestamp > cutoffTime }

        if recentAttempts.count >= maxAttempts {
            let oldestRecentAttempt = recentAttempts.min(by: { $0.timestamp < $1.timestamp })
            let retryAfterSeconds = Int(oldestRecentAttempt?.timestamp.addingTimeInterval(TimeInterval(timeWindowMinutes * 60)).timeIntervalSinceNow ?? 0)
            return .failure(.rateLimitExceeded(retryAfterSeconds: max(retryAfterSeconds, 0)))
        }

        return .success(())
    }

    public func recordAttempt(for email: String, ipAddress: String?) {
        let attempt = PasswordRecoveryAttempt(email: email, timestamp: Date(), ipAddress: ipAddress)
        attemptWriter.recordAttempt(attempt)
    }
}
