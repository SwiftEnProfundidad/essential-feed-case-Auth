import Foundation

public enum SessionError: Error {
    case tokenRefreshFailed
}

public final class AuthenticatedHTTPClientDecorator: HTTPClient, @unchecked Sendable {
    private let client: HTTPClient
    private let tokenStorage: TokenStorage
    private let refreshTokenUseCase: RefreshTokenUseCase
    private let sessionManager: SessionManaging
    private let validationStrategy: TokenValidationStrategy
    private let routePolicy: RouteAuthenticationPolicy

    public init(
        client: HTTPClient,
        tokenStorage: TokenStorage,
        refreshTokenUseCase: RefreshTokenUseCase,
        sessionManager: SessionManaging,
        validationStrategy: TokenValidationStrategy = ExpiryTokenValidationStrategy(),
        routePolicy: RouteAuthenticationPolicy = PathBasedRoutePolicy()
    ) {
        self.client = client
        self.tokenStorage = tokenStorage
        self.refreshTokenUseCase = refreshTokenUseCase
        self.sessionManager = sessionManager
        self.validationStrategy = validationStrategy
        self.routePolicy = routePolicy
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // Si no requiere autenticación, enviar directamente
        guard routePolicy.requiresAuthentication(request) else {
            return try await client.send(request)
        }

        // Intentar cargar token y añadir auth header si es válido
        let authenticatedRequest = await addAuthHeaderIfPossible(to: request)

        do {
            return try await client.send(authenticatedRequest)
        } catch {
            // Si es error 401 y tenemos refresh token, intentar refresh
            if isUnauthorizedError(error) {
                return try await handleUnauthorizedError(for: request)
            }
            throw error
        }
    }

    private func addAuthHeaderIfPossible(to request: URLRequest) async -> URLRequest {
        do {
            if let token = try await tokenStorage.loadTokenBundle(),
               validationStrategy.isValid(token)
            {
                var request = request
                request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
                return request
            }
        } catch {
            // Si falla la carga del token, continuar sin auth
        }
        return request
    }

    private func handleUnauthorizedError(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // Intentar refresh del token
        let refreshedToken = try await refreshTokenUseCase.execute()
        try await tokenStorage.save(tokenBundle: refreshedToken)

        // Reintentar con el nuevo token
        var authenticatedRequest = request
        authenticatedRequest.setValue("Bearer \(refreshedToken.accessToken)", forHTTPHeaderField: "Authorization")
        return try await client.send(authenticatedRequest)
    }

    private func isUnauthorizedError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .userAuthenticationRequired
        }
        return false
    }
}
