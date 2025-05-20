import Foundation

public struct Token: Equatable, Codable {
    public let accessToken: String
    public let expiry: Date
    public let refreshToken: String?

    public init(accessToken: String, expiry: Date, refreshToken: String?) {
        self.accessToken = accessToken
        self.expiry = expiry
        self.refreshToken = refreshToken
    }

    public static func == (lhs: Token, rhs: Token) -> Bool {
        let tolerance: TimeInterval = 1.0
        return lhs.accessToken == rhs.accessToken &&
            abs(lhs.expiry.timeIntervalSince(rhs.expiry)) < tolerance &&
            lhs.refreshToken == rhs.refreshToken
    }
}
