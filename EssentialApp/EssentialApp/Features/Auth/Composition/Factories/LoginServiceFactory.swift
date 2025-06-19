@preconcurrency import EssentialFeed
import Foundation

enum LoginServiceFactory {
    static func makeLoginService(
        config: UserLoginConfiguration,
        loginAPI: UserLoginAPI,
        tokenStorage: TokenStorage
    ) -> LoginService {
        let offlineStore = InMemoryOfflineLoginStore()
        let loginPersistence = DefaultLoginPersistence(
            tokenStorage: tokenStorage,
            offlineStore: offlineStore,
            config: config
        )

        let validator = LoginCredentialsValidator()
        let failedLoginStore = InMemoryFailedLoginAttemptsStore()

        let securityConfig = LoginSecurityConfiguration(
            maxAttempts: config.maxFailedAttempts,
            blockDuration: config.lockoutDuration,
            captchaThreshold: LoginSecurityConfiguration.default.captchaThreshold
        )

        let securityUseCase = LoginSecurityUseCase(
            store: failedLoginStore,
            configuration: securityConfig
        )

        return DefaultLoginService(
            validator: validator,
            securityUseCase: securityUseCase,
            api: loginAPI,
            persistence: loginPersistence,
            config: config
        )
    }
}
