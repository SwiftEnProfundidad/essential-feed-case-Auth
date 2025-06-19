import Foundation

public enum LoginSecurityServiceFactory {
    public static func create(
        store: FailedLoginAttemptsStore = InMemoryFailedLoginAttemptsStore(),
        maxAttempts: Int = 5,
        blockDuration: TimeInterval = 300,
        captchaThreshold: Int = 3,
        timeProvider: @escaping () -> Date = { Date() }
    ) -> DefaultLoginSecurityServiceUseCase {
        let configuration = LoginSecurityConfiguration(
            maxAttempts: maxAttempts,
            blockDuration: blockDuration,
            captchaThreshold: captchaThreshold
        )
        return DefaultLoginSecurityServiceUseCase(
            store: store,
            configuration: configuration,
            timeProvider: timeProvider
        )
    }
}
