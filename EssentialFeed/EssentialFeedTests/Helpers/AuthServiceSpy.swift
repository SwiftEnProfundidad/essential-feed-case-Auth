import EssentialFeed
import Foundation

class AuthServiceSpy {
    private(set) var messages = [LoginRequest]()
    var stubbedResult: Result<LoginResponse, LoginError> = .failure(.unknown)

    func authenticate(email: String, password: String) async -> Result<LoginResponse, LoginError> {
        let request = LoginRequest(username: email, password: password)
        messages.append(request)
        return stubbedResult
    }
}

// MARK: - Helpers

extension LoginRequest {
    init(credentials: LoginCredentials) {
        self.init(username: credentials.email, password: credentials.password)
    }
}
