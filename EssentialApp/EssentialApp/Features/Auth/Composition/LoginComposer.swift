import Combine
import EssentialFeed
import SwiftUI
import UIKit

public enum LoginComposer {
    private static var cancellables = Set<AnyCancellable>()
    public static func loginViewController(onAuthenticated: @escaping () -> Void) -> UIViewController {
        let authenticate: (String, String) async -> Result<LoginResponse, LoginError> = { username, password in
            // Aquí debemos llamar a nuestra API real de login (ajustar según infraestructura)
            // Por ejemplo:
            // return await api.login(username: username, password: password)
            // Por ahora, devolvemos un dummy para compilar:
            if username == "user", password == "pass" {
                .success(LoginResponse(token: "dummy_token"))
            } else {
                .failure(.invalidCredentials)
            }
        }
        let viewModel = LoginViewModel(authenticate: authenticate)
        viewModel.onAuthenticated = onAuthenticated
        let loginView = LoginView(viewModel: viewModel)
        let controller = UIHostingController(rootView: loginView)
        return controller
    }
}
