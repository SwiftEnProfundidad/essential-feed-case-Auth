import Foundation

public final class GlobalLogoutInterceptor: HTTPClientInterceptor {
    private let logoutManager: SessionLogoutManager

    public init(logoutManager: SessionLogoutManager) {
        self.logoutManager = logoutManager
    }

    public func intercept(_ request: URLRequest, next: HTTPClient) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await next.send(request)
        } catch {
            if isTokenRefreshError(error) {
                try await logoutManager.performGlobalLogout()
                throw SessionError.globalLogoutRequired
            }
            throw error
        }
    }

    private func isTokenRefreshError(_ error: Error) -> Bool {
        if let sessionError = error as? SessionError {
            return sessionError == .tokenRefreshFailed
        }
        return false
    }
}
