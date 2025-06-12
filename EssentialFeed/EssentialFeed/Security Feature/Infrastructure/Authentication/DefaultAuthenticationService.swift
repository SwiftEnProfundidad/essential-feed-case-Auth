import Foundation

public final class DefaultAuthenticationService: AuthenticationService {
    private let tokenStorage: TokenStorage
    private let validationStrategy: TokenValidationStrategy
    private let refreshCoordinator: RefreshCoordinator

    public init(
        tokenStorage: TokenStorage,
        validationStrategy: TokenValidationStrategy,
        refreshCoordinator: RefreshCoordinator
    ) {
        self.tokenStorage = tokenStorage
        self.validationStrategy = validationStrategy
        self.refreshCoordinator = refreshCoordinator
    }

    public func authenticateRequest(_ request: URLRequest) async -> URLRequest {
        do {
            if let token = try await tokenStorage.loadTokenBundle(),
               validationStrategy.isValid(token)
            {
                var authenticatedRequest = request
                authenticatedRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
                return authenticatedRequest
            }
        } catch {}
        return request
    }

    public func handleAuthenticationFailure(for request: URLRequest) async throws -> URLRequest {
        let refreshedToken = try await refreshCoordinator.getRefreshedToken()
        var retryRequest = request
        retryRequest.setValue("Bearer \(refreshedToken.accessToken)", forHTTPHeaderField: "Authorization")
        return retryRequest
    }
}
