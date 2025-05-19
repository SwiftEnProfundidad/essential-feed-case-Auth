import Foundation

public protocol TokenRefreshService {
    func refreshToken(refreshToken: String) async -> Result<TokenRefreshResult, TokenRefreshError>
}

public struct TokenRefreshResult: Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiry: Date

    public init(accessToken: String, refreshToken: String, expiry: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiry = expiry
    }
}

public enum TokenRefreshError: Error, Equatable {
    case invalidRefreshToken
    case network
    case server(message: String)
    case unknown
}
