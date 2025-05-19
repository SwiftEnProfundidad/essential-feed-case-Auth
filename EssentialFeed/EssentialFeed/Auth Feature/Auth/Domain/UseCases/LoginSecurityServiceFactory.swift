import Foundation

public enum LoginSecurityServiceFactory {
    public static func create(
        store: FailedLoginAttemptsStore = InMemoryFailedLoginAttemptsStore(),
        maxAttempts: Int = 5,
        blockDuration: TimeInterval = 300,
        timeProvider: @escaping () -> Date = { Date() }
    ) -> DefaultLoginSecurityServiceUseCase {
        DefaultLoginSecurityServiceUseCase(
            store: store,
            maxAttempts: maxAttempts,
            blockDuration: blockDuration,
            timeProvider: timeProvider
        )
    }
}
