import Foundation

extension RefreshTokenResponse {
    func toTokenRefreshResult() -> TokenRefreshResult {
        TokenRefreshResult(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiry: Date().addingTimeInterval(expiresIn)
        )
    }
}

// MARK: - Helpers

private extension Date {
    func adding(seconds: TimeInterval) -> Date {
        addingTimeInterval(seconds)
    }
}
