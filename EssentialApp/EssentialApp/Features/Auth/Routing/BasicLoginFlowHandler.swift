import EssentialFeed
import Foundation

@MainActor
class BasicLoginFlowHandler: LoginFlowHandler {
    var onAuthenticated: (() -> Void)?

    func handlePostLogin(result: Result<LoginResponse, LoginError>, credentials _: LoginCredentials) async {
        switch result {
        case .success:
            onAuthenticated?()
        case .failure:
            break
        }
    }

    func handlePostLogout(result: Result<Void, Error>) async {
        switch result {
        case .success:
            break
        case .failure:
            break
        }
    }
}
