
import Foundation

public struct LoginResponse: Equatable {
    public let user: User
    public let token: Token

    public init(user: User, token: Token) {
        self.user = user
        self.token = token
    }
}
