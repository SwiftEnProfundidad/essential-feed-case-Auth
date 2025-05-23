import EssentialFeed

class TokenRefreshServiceSpy: TokenRefreshService {
    private(set) var messages = [String]()
    var stubbedResult: Result<TokenRefreshResult, TokenRefreshError> = .failure(.unknown)

    func refreshToken(refreshToken: String) async -> Result<TokenRefreshResult, TokenRefreshError> {
        messages.append(refreshToken)
        return stubbedResult
    }
}

// MARK: - Helpers

public extension TokenRefreshResult {
    static func == (lhs: TokenRefreshResult, rhs: TokenRefreshResult) -> Bool {
        lhs.accessToken == rhs.accessToken &&
            lhs.refreshToken == rhs.refreshToken &&
            lhs.expiry == rhs.expiry
    }
}
