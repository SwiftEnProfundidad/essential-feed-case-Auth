import Foundation

public struct RegistrationContext {
    public let userData: UserRegistrationData
    public var request: URLRequest?
    public var protectedRequest: URLRequest?
    public var httpResponse: (Data, HTTPURLResponse)?
    public var tokenAndUser: TokenAndUser?
    public var savedUser: User?

    public init(userData: UserRegistrationData) {
        self.userData = userData
    }
}
