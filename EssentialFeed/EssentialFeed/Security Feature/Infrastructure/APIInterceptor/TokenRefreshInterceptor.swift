import Foundation

public final class TokenRefreshInterceptor: HTTPClientInterceptor {
    private let refreshTokenUseCase: RefreshTokenUseCase
    private let tokenStorage: TokenWriter

    public init(refreshTokenUseCase: RefreshTokenUseCase, tokenStorage: TokenWriter) {
        self.refreshTokenUseCase = refreshTokenUseCase
        self.tokenStorage = tokenStorage
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
        let refreshedToken = try await refreshTokenUseCase.execute()
        try await tokenStorage.save(tokenBundle: refreshedToken)

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
