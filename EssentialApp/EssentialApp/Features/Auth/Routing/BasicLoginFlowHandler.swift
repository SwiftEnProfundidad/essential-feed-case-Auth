import EssentialFeed
import Foundation

@MainActor
class BasicLoginFlowHandler: LoginFlowHandler {
    var onAuthenticated: (() -> Void)?

    func handlePostLogin(result: Result<LoginResponse, LoginError>, credentials _: LoginCredentials) async {
        switch result {
        case .success:
            print("FlowHandler: Login successful. Calling onAuthenticated.")
            onAuthenticated?()
        case let .failure(error):
            print("FlowHandler: Login failed with error: \(error). Not calling onAuthenticated.")
            // Aquí se podría manejar la presentación de errores específicos en la UI si fuera necesario
        }
    }

    func handlePostLogout(result: Result<Void, Error>) async {
        switch result {
        case .success:
            print("FlowHandler: Logout successful.")
        // Aquí se podría manejar la navegación a la pantalla de login, por ejemplo.
        case let .failure(error):
            print("FlowHandler: Logout failed with error: \(error).")
        }
    }
}
