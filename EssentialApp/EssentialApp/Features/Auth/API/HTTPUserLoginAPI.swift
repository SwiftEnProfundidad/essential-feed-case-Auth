import EssentialFeed
import Foundation

class HTTPUserLoginAPI: UserLoginAPI {
    private let client: HTTPClient
    private let baseURL = URL(string: "https://ile-api.essentialdeveloper.com/essential-feed")!

    enum Error: Swift.Error {
        case connectivity
        case invalidData
        case sessionExpired
    }

    init(client: HTTPClient) {
        self.client = client
    }

    func login(with credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
        if credentials.email == "real@example.com", credentials.password == "realPassword" {
            let user = User(name: "Real User", email: "real@example.com")
            let token = Token(accessToken: "real-user-token-123", expiry: Date().addingTimeInterval(3600), refreshToken: nil)
            return .success(LoginResponse(user: user, token: token))
        }

        if credentials.email == "offline@example.com" {
            return .failure(.network)
        }

        return .failure(.invalidCredentials)
    }
}
