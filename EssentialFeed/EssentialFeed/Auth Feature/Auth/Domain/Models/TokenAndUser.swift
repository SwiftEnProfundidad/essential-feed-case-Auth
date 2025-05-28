import Foundation

public struct TokenAndUser {
    public let token: Token
    public let user: User

    public init(token: Token, user: User) {
        self.token = token
        self.user = user
    }
}
