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
        let tokenStorage = KeychainDependencyFactory.makeTokenStorage()

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
    @MainActor static func makeLoginFlowHandler(onAuthenticated: @escaping () -> Void) -> BasicLoginFlowHandler {
        let loginFlowHandler = BasicLoginFlowHandler()
        loginFlowHandler.onAuthenticated = onAuthenticated
        return loginFlowHandler
    }

    static func makeLoginViewModel(userLoginUseCase: UserLoginUseCase) -> LoginViewModel {
        LoginViewModel(authenticate: { email, password in
            await userLoginUseCase.login(with: LoginCredentials(email: email, password: password))
        })
    }
}
