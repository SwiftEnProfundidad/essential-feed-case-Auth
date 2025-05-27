import Foundation

public struct LoginCredentials: Equatable, Codable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}
