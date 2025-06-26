@preconcurrency import EssentialFeed
import SwiftUI
import UIKit

public enum LoginComposer {
    @MainActor public static func composedLoginViewController(
        onAuthenticated: @escaping () -> Void,
        onRecoveryRequested: @escaping () -> Void,
        onRegisterRequested: @escaping () -> Void
    ) -> UIViewController {
        let config = ConfigurationFactory.makeUserLoginConfiguration()
        let httpClient = NetworkDependencyFactory.makeHTTPClient()
        let loginAPI = NetworkDependencyFactory.makeLoginAPI(httpClient: httpClient)
        let tokenStorage = NetworkDependencyFactory.makeTokenStorage()

        _ = makeLoginFlowHandler(onAuthenticated: onAuthenticated)
        let loginService = LoginServiceFactory.makeLoginService(
            config: config,
            loginAPI: loginAPI,
            tokenStorage: tokenStorage
        )

        let userLoginUseCase = UserLoginUseCase(loginService: loginService)
        let viewModel = makeLoginViewModel(userLoginUseCase: userLoginUseCase)

        return LoginUIComposer.composedLoginViewController(
            with: viewModel,
            onRecoveryRequested: onRecoveryRequested,
            onRegisterRequested: onRegisterRequested
        )
    }
}

// MARK: - Private Factory Methods

private extension LoginComposer {
    @MainActor static func makeLoginFlowHandler(onAuthenticated: @escaping () -> Void)
        -> BasicLoginFlowHandler
    {
        let loginFlowHandler = BasicLoginFlowHandler()
        loginFlowHandler.onAuthenticated = onAuthenticated
        return loginFlowHandler
    }

    static func makeLoginViewModel(userLoginUseCase: UserLoginUseCase) -> LoginViewModel {
        let config = ConfigurationFactory.makeUserLoginConfiguration()

        let securityConfig = LoginSecurityConfiguration(
            maxAttempts: config.maxFailedAttempts,
            blockDuration: config.lockoutDuration,
            captchaThreshold: LoginSecurityConfiguration.default.captchaThreshold
        )

        let failedAttemptsStore = InMemoryFailedLoginAttemptsStore()

        let loginSecurity = LoginSecurityUseCase(
            store: failedAttemptsStore,
            configuration: securityConfig
        )

        let httpClient = NetworkDependencyFactory.makeHTTPClient()
        let captchaValidator = NetworkDependencyFactory.makeCaptchaValidator(httpClient: httpClient)

        let captchaCoordinator = DefaultCaptchaFlowCoordinator(
            captchaValidator: captchaValidator,
            failedAttemptsStore: failedAttemptsStore,
            configuration: securityConfig
        )

        let blockMessageProvider = DefaultLoginBlockMessageProvider()

        return LoginViewModel(
            authenticate: { email, password in
                await userLoginUseCase.login(with: LoginCredentials(email: email, password: password))
            },
            pendingRequestStore: nil,
            loginSecurity: loginSecurity,
            blockMessageProvider: blockMessageProvider,
            captchaFlowCoordinator: captchaCoordinator
        )
    }
}
