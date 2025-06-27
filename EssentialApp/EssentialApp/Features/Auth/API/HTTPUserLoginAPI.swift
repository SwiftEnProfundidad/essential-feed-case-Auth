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
        // ⚠️ TEMPORAL: Hardcoded credentials for demo purposes
        // TODO: PRODUCTION - Remove hardcoded credentials and implement real API calls
        // This should make actual HTTP requests to the authentication backend

        let credentialKey = "\(credentials.email):\(credentials.password)"

        switch credentialKey {
        case "admin:admin":
            return createSuccessResponse(name: "Admin User", email: "admin@app.com", loginKey: "admin")
        case "user:pass":
            return createSuccessResponse(name: "Test User", email: "user@test.com", loginKey: "user")
        case "demo:demo":
            return createSuccessResponse(name: "Demo User", email: "demo@app.com", loginKey: "demo")
        case "test:test":
            return createSuccessResponse(name: "Test Account", email: "test@example.com", loginKey: "test")
        case "real@example.com:realPassword":
            return createSuccessResponse(name: "Real User", email: "real@example.com", loginKey: "real")
        default:
            if credentials.email == "offline@example.com" {
                return .failure(.network)
            }
            print("❌ Login failed for: \(credentials.email)")
            return .failure(.invalidCredentials)
        }
    }

    private func createSuccessResponse(name: String, email: String, loginKey: String) -> Result<LoginResponse, LoginError> {
        let user = User(name: name, email: email)
        let token = Token(
            accessToken: "\(loginKey)-token-\(UUID().uuidString.prefix(8))",
            expiry: Date().addingTimeInterval(3600),
            refreshToken: nil
        )
        print("✅ Login successful for: \(email) -> \(name)")
        return .success(LoginResponse(user: user, token: token))
    }
}
