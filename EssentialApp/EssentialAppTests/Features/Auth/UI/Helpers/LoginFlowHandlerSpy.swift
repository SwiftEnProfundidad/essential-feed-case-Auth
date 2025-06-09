import EssentialFeed
import Foundation

class LoginFlowHandlerSpy: LoginFlowHandler {
    private(set) var handlePostLoginCalls: [(Result<LoginResponse, LoginError>, LoginCredentials)] = []

    func handlePostLogin(result: Result<LoginResponse, LoginError>, credentials: LoginCredentials) async {
        handlePostLoginCalls.append((result, credentials))
    }
}
