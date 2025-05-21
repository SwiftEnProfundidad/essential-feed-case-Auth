import Foundation

public struct ServerAuthResponse: Codable {
    public struct UserPayload: Codable {
        let name: String
        let email: String

        public init(name: String, email: String) {
            self.name = name
            self.email = email
        }
    }

    public struct TokenPayload: Codable {
        let value: String
        let expiry: Date

        public init(value: String, expiry: Date) {
            self.value = value
            self.expiry = expiry
        }
    }

    let user: UserPayload
    let token: TokenPayload

    public init(user: UserPayload, token: TokenPayload) {
        self.user = user
        self.token = token
    }
}
