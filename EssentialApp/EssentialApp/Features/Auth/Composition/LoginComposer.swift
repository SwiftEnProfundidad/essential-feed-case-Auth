import EssentialFeed
import SwiftUI

public enum LoginComposer {
    public static func composedViewController(onAuthenticated: @escaping () -> Void) -> UIViewController {
        let viewModel = LoginViewModel(authenticate: { email, _ in
            // En modo desarrollo (pero no en tests), aceptamos cualquier credencial
            #if DEBUG && !(TESTING || testing)
                print("🔑 Desarrollo: Login automático aceptado para \"\(email)\"")
                return .success(LoginResponse(token: "desarrollo-token-123456"))
            #else
                // En tests o producción, usamos la lógica normal
                return .failure(LoginError.invalidCredentials)
            #endif
        })

        viewModel.onAuthenticated = onAuthenticated
        let view = LoginView(viewModel: viewModel)

        return UIHostingController(rootView: view)
    }
}
