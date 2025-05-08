import Combine
import EssentialFeed
import SwiftUI
import UIKit

public enum LoginComposer {
    private static var cancellables = Set<AnyCancellable>()
    public static func loginViewController(
        onAuthenticated: @escaping () -> Void) -> UIViewController {
        let authenticate: (String, String) async -> Result<LoginResponse, LoginError> = { username, password in
            // Aquí deberías llamar a tu API real de login (ajusta según tu infraestructura):
            // Por ejemplo:
            // return await api.login(username: username, password: password)
            // Por ahora, devolvemos un dummy para compilar:
            if username == "user" && password == "pass" {
                return .success(LoginResponse(token: "dummy_token"))
            } else {
                return .failure(.invalidCredentials)
            }
        }
        let viewModel = LoginViewModel(authenticate: authenticate)
        viewModel.onAuthenticated = onAuthenticated
        let loginView = LoginView(viewModel: viewModel)
        let controller = UIHostingController(rootView: loginView)
        return controller
    }
}
