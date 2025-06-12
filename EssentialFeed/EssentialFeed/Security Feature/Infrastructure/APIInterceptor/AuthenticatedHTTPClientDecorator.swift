import Foundation

public enum SessionError: Error {
    case tokenRefreshFailed
    case globalLogoutRequired
}

public protocol AuthenticationService {
    func authenticateRequest(_ request: URLRequest) async -> URLRequest
    func handleAuthenticationFailure(for request: URLRequest) async throws -> URLRequest
}

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

public protocol TokenRefreshCoordinator {
    func getRefreshedToken() async throws -> Token
}

public actor RefreshCoordinator: TokenRefreshCoordinator {
    private let refreshTokenUseCase: RefreshTokenUseCase
    private let tokenStorage: TokenStorage

    private var refreshTask: Task<Token, Error>?

    public init(refreshTokenUseCase: RefreshTokenUseCase, tokenStorage: TokenStorage) {
        self.refreshTokenUseCase = refreshTokenUseCase
        self.tokenStorage = tokenStorage
    }

    public func getRefreshedToken() async throws -> Token {
        if let existingTask = refreshTask {
            return try await existingTask.value
        }

        let newTask = Task<Token, Error> {
            do {
                let token = try await self.refreshTokenUseCase.execute()
                try await self.tokenStorage.save(tokenBundle: token)
                return token
            } catch {
                if self.isNetworkError(error) {
                    throw error
                } else {
                    throw SessionError.tokenRefreshFailed
                }
            }
        }

        refreshTask = newTask

        do {
            let result = try await newTask.value
            refreshTask = nil
            return result
        } catch {
            refreshTask = nil
            throw error
        }
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
