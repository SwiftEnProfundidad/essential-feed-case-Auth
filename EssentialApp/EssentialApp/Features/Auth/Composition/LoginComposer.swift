import EssentialFeed
import SwiftUI
import UIKit

public enum LoginComposer {
    @MainActor public static func composedLoginViewController(
        onAuthenticated: @escaping () -> Void,
        onRecoveryRequested: @escaping () -> Void
    ) -> UIViewController {
        let httpClient = URLSessionHTTPClient(session: URLSession(configuration: .ephemeral))

        let loginAPI = HTTPUserLoginAPI(client: httpClient)
        let loginPersistence = UserDefaultsLoginPersistence()
        let loginNotifier = ConsoleLoginEventNotifier()
        let loginFlowHandler = BasicLoginFlowHandler()
        loginFlowHandler.onAuthenticated = onAuthenticated

        let lockStatusProvider = InMemoryLoginLockStatusProvider(lockoutDuration: 300)
        let failedLoginHandler = InMemoryFailedLoginHandler(maxAttempts: 3, lockStatusProvider: lockStatusProvider)
        let config = UserLoginConfiguration(
            maxFailedAttempts: 3,
            lockoutDuration: 300,
            tokenDuration: 3600
        )

        let userLoginUseCase = UserLoginUseCase(
            api: loginAPI,
            persistence: loginPersistence,
            notifier: loginNotifier,
            flowHandler: loginFlowHandler,
            lockStatusProvider: lockStatusProvider,
            failedLoginHandler: failedLoginHandler,
            config: config
        )

        let viewModel = LoginViewModel(authenticate: { email, password in
            await userLoginUseCase.login(with: LoginCredentials(email: email, password: password))
        })

        return LoginUIComposer.composedLoginViewController(with: viewModel, onRecoveryRequested: onRecoveryRequested)
    }
}
