import EssentialFeed
import Foundation

final class TokenRefreshServiceStub: TokenRefreshService {
    let failCount: Int
    let alwaysFail: Bool
    var attempt = 0

    init(fails: Int, alwaysFail: Bool) {
        self.failCount = fails
        self.alwaysFail = alwaysFail
    }

    func refreshToken(refreshToken _: String) async -> Result<TokenRefreshResult, TokenRefreshError> {
        attempt += 1
        if alwaysFail {
            try? await Task.sleep(nanoseconds: 10_000_000)
            return .failure(.network)
        }
        if attempt <= failCount {
            try? await Task.sleep(nanoseconds: 10_000_000)
            return .failure(.network)
        }
        let expiry = Date().addingTimeInterval(3600)
        let result = TokenRefreshResult(accessToken: "newAccessToken", refreshToken: "newRefreshToken", expiry: expiry)
        return .success(result)
    }

    func resetAttempt() {
        self.attempt = 0
    }
}
