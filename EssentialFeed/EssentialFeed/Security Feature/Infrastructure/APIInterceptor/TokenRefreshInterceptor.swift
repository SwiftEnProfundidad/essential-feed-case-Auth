import Foundation

public final class TokenRefreshInterceptor: HTTPClientInterceptor {
    private let tokenRefreshHandler: TokenRefreshHandler

    public init(refreshTokenUseCase: RefreshTokenUseCase, tokenStorage: TokenWriter) {
        self.tokenRefreshHandler = TokenRefreshHandler(
            refreshTokenUseCase: refreshTokenUseCase,
            tokenStorage: tokenStorage
        )
    }

    public func intercept(_ request: URLRequest, next: HTTPClient) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await next.send(request)
        } catch {
            guard isUnauthorizedError(error) else {
                throw error
            }
            return try await handleTokenRefreshAndRetry(for: request, next: next)
        }
    }

    private func handleTokenRefreshAndRetry(for request: URLRequest, next: HTTPClient) async throws -> (Data, HTTPURLResponse) {
        let refreshedToken = try await tokenRefreshHandler.getRefreshedToken()

        var authenticatedRequest = request
        authenticatedRequest.setValue("Bearer \(refreshedToken.accessToken)", forHTTPHeaderField: "Authorization")
        return try await next.send(authenticatedRequest)
    }

    private func isUnauthorizedError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .userAuthenticationRequired
        }
        return false
    }
}
