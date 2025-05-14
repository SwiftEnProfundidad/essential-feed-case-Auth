import Foundation

public protocol UserLoginAPI {
    func login(with credentials: LoginCredentials) async -> Result<LoginResponse, LoginError>
}
