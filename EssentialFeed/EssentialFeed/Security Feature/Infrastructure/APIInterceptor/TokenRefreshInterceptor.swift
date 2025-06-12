import Foundation

public final class TokenRefreshInterceptor: HTTPClientInterceptor {
    private let tokenRefreshHandler: TokenRefreshHandler

    public init(refreshHandler: TokenRefreshHandler) {
        self.tokenRefreshHandler = refreshHandler
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
        do {
            let refreshedToken = try await tokenRefreshHandler.getRefreshedToken()
            var authenticatedRequest = request
            authenticatedRequest.setValue("Bearer \(refreshedToken.accessToken)", forHTTPHeaderField: "Authorization")
            return try await next.send(authenticatedRequest)
        } catch {
            throw SessionError.tokenRefreshFailed
        }
    }

    private func isUnauthorizedError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .userAuthenticationRequired
        }
        return false
    }
}
