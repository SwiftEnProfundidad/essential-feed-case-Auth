
import Foundation

public struct LoginResponse: Equatable {
    public let token: String

    public init(token: String) {
        self.token = token
    }
}
