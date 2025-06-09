import EssentialFeed
import Foundation

class UserLoginAPISpy: UserLoginAPI {
    var stubbedResult: Result<LoginResponse, LoginError> = .failure(.invalidCredentials)
    private(set) var loginCalls: [LoginCredentials] = []

    func login(with credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
        loginCalls.append(credentials)
        return stubbedResult
    }
}
