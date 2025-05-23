import EssentialFeed
import SwiftUI
import UIKit

public enum LoginComposer {
    @MainActor public static func composedLoginViewController(
        onAuthenticated: @escaping () -> Void,
        onRecoveryRequested: @escaping () -> Void
    ) -> UIViewController {
        // 1. Crear HTTPClient
        // Usamos .ephemeral para no guardar cookies/cache entre sesiones de app, similar a SceneDelegate
        let httpClient = URLSessionHTTPClient(session: URLSession(configuration: .ephemeral))

        // 2. Crear dependencias concretas para UserLoginUseCase
        let loginAPI = HTTPUserLoginAPI(client: httpClient)
        let loginPersistence = UserDefaultsLoginPersistence() // Usa UserDefaults.standard por defecto
        let loginNotifier = ConsoleLoginEventNotifier()
        let loginFlowHandler = BasicLoginFlowHandler()
        loginFlowHandler.onAuthenticated = onAuthenticated // Conectar el callback

        // 3. Crear UserLoginUseCase
        let userLoginUseCase = UserLoginUseCase(
            api: loginAPI,
            persistence: loginPersistence,
            notifier: loginNotifier,
            flowHandler: loginFlowHandler
            // config y userDefaults pueden usar valores por defecto o ser más configurados si es necesario
        )

        // 4. Crear LoginViewModel con el UserLoginUseCase real
        let viewModel = LoginViewModel(authenticate: { email, password in
            // Llamar al UserLoginUseCase real
            await userLoginUseCase.login(with: LoginCredentials(email: email, password: password))
        })

        // El onAuthenticated original del LoginComposer se pasa al flowHandler,
        // y el flowHandler lo llama. El viewModel.onAuthenticated ya no es necesario aquí
        // si el flowHandler maneja la navegación/actualización de UI post-autenticación.
        // Sin embargo, si LoginViewModel tiene su propio `onAuthenticated` para lógica de UI interna,
        // se podría conectar también.
        // viewModel.onAuthenticated = onAuthenticated // Esto podría ser redundante o para otra cosa

        return LoginUIComposer.composedLoginViewController(with: viewModel, onRecoveryRequested: onRecoveryRequested)
    }
}
