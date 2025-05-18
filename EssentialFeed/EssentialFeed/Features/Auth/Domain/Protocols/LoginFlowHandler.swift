import Foundation

public protocol LoginFlowHandler {
    func handlePostLogin(result: Result<LoginResponse, LoginError>, credentials: LoginCredentials) async
}
