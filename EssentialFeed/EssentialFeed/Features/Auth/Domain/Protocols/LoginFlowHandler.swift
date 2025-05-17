import Foundation

public protocol LoginFlowHandler {
    func handlePostLogin(result: Result<LoginResponse, Error>, credentials: LoginCredentials) async
}
