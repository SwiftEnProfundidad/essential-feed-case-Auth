import Foundation

public protocol LoginService {
    func execute(credentials: LoginCredentials) async -> Result<LoginResponse, LoginError>
}
