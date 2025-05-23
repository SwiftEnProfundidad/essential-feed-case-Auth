import Foundation

public struct RefreshTokenResponse: Equatable, Codable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: TimeInterval

    public init(accessToken: String, refreshToken: String, expiresIn: TimeInterval) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
    }
}
