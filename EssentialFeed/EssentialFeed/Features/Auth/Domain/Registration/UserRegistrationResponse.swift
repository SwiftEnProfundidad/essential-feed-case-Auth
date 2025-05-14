public struct UserRegistrationResponse: Equatable {
    public let userID: String
    public let token: String
    public let refreshToken: String?

    public init(userID: String, token: String, refreshToken: String?) {
        self.userID = userID
        self.token = token
        self.refreshToken = refreshToken
    }
}
