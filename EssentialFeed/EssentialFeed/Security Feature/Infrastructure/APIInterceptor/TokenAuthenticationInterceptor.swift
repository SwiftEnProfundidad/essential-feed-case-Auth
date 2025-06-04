import Foundation

public final class TokenAuthenticationInterceptor: HTTPClient, @unchecked Sendable {
    private let client: HTTPClient
    private let tokenStorage: TokenReader
    private let validationStrategy: TokenValidationStrategy
    private let routePolicy: RouteAuthenticationPolicy

    public init(
        client: HTTPClient,
        tokenStorage: TokenReader,
        validationStrategy: TokenValidationStrategy,
        routePolicy: RouteAuthenticationPolicy
    ) {
        self.client = client
        self.tokenStorage = tokenStorage
        self.validationStrategy = validationStrategy
        self.routePolicy = routePolicy
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // Si no requiere autenticación, enviar directamente
        guard routePolicy.requiresAuthentication(request) else {
            return try await client.send(request)
        }

        // Intentar cargar token
        do {
            if let token = try await tokenStorage.loadTokenBundle(),
               validationStrategy.isValid(token)
            {
                let authenticatedRequest = addToken(token.accessToken, to: request)
                return try await client.send(authenticatedRequest)
            }
        } catch {
            // Si falla la carga del token, continuar sin autenticación
        }

        // Enviar sin autenticación si no hay token válido
        return try await client.send(request)
    }

    private func addToken(_ token: String, to request: URLRequest) -> URLRequest {
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
