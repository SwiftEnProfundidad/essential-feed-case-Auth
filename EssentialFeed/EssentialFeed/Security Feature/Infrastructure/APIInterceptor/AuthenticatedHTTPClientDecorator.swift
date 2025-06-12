import Foundation

public final class AuthenticatedHTTPClientDecorator: HTTPClient, @unchecked Sendable {
    private let client: HTTPClient
    private let tokenStorage: TokenStorage
    private let refreshTokenUseCase: RefreshTokenUseCase
    private let logoutManager: SessionLogoutManager
    private let validationStrategy: TokenValidationStrategy
    private let routePolicy: RouteAuthenticationPolicy

    private let refreshCoordinator: RefreshCoordinator

    public init(
        client: HTTPClient,
        tokenStorage: TokenStorage,
        refreshTokenUseCase: RefreshTokenUseCase,
        logoutManager: SessionLogoutManager,
        validationStrategy: TokenValidationStrategy = ExpiryTokenValidationStrategy(),
        routePolicy: RouteAuthenticationPolicy = PathBasedRoutePolicy()
    ) {
        self.client = client
        self.tokenStorage = tokenStorage
        self.refreshTokenUseCase = refreshTokenUseCase
        self.logoutManager = logoutManager
        self.validationStrategy = validationStrategy
        self.routePolicy = routePolicy
        self.refreshCoordinator = RefreshCoordinator(
            refreshTokenUseCase: refreshTokenUseCase,
            tokenStorage: tokenStorage
        )
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard routePolicy.requiresAuthentication(request) else {
            return try await client.send(request)
        }

        let authenticatedRequest = await addAuthHeaderIfValid(to: request)

        do {
            return try await client.send(authenticatedRequest)
        } catch {
            guard isUnauthorizedError(error) else {
                throw error
            }

            do {
                let refreshedToken = try await refreshCoordinator.getRefreshedToken()
                var retryRequest = request
                retryRequest.setValue("Bearer \(refreshedToken.accessToken)", forHTTPHeaderField: "Authorization")
                return try await client.send(retryRequest)
            } catch {
                if isNetworkError(error) {
                    throw error
                } else {
                    try await logoutManager.performGlobalLogout()
                    throw SessionError.globalLogoutRequired
                }
            }
        }
    }

    private func addAuthHeaderIfValid(to request: URLRequest) async -> URLRequest {
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

    private func isUnauthorizedError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .userAuthenticationRequired
        }
        return false
    }

    private func isNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost, .notConnectedToInternet, .timedOut, .cannotConnectToHost, .cannotFindHost:
                return true
            default:
                return false
            }
        }
        return false
    }
}
