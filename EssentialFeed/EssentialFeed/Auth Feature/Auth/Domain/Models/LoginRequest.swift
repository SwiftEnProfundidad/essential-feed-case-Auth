public struct LoginRequest: Codable, Equatable {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

// MARK: - Helpers

public extension LoginRequest {
    func toCredentials() -> LoginCredentials {
        LoginCredentials(email: username, password: password)
    }
}
