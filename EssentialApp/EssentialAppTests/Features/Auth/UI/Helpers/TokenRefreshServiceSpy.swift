import EssentialFeed
import Foundation

final class TokenRefreshServiceSpy: TokenRefreshService {
    private(set) var refreshTokenCallCount = 0
    private(set) var receivedRefreshTokens: [String] = []
    private var stubbedResult: Result<TokenRefreshResult, TokenRefreshError>?

    func completeRefresh(with result: Result<TokenRefreshResult, TokenRefreshError>) {
        stubbedResult = result
    }

    func refreshToken(refreshToken: String) async -> Result<TokenRefreshResult, TokenRefreshError> {
        refreshTokenCallCount += 1
        receivedRefreshTokens.append(refreshToken)

        return stubbedResult ?? .failure(.invalidRefreshToken)
    }
}
