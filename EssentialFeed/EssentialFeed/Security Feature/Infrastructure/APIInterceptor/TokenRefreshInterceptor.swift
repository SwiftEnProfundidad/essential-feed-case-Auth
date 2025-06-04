import Foundation

public final class TokenRefreshInterceptor: HTTPClient, @unchecked Sendable {
    private let client: HTTPClient
    private let refreshTokenUseCase: RefreshTokenUseCase
    private let tokenStorage: TokenWriter

    public init(
        client: HTTPClient,
        refreshTokenUseCase: RefreshTokenUseCase,
        tokenStorage: TokenWriter
    ) {
        self.client = client
        self.refreshTokenUseCase = refreshTokenUseCase
        self.tokenStorage = tokenStorage
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await client.send(request)
        } catch {
            // Si es error 401, intentar refresh y reintentar
            if isUnauthorizedError(error) {
                let refreshedToken = try await refreshTokenUseCase.execute()
                try await tokenStorage.save(tokenBundle: refreshedToken)

                // Reintentar con el nuevo token
                return try await client.send(request)
            }

            throw error
        }
    }

    private func isUnauthorizedError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .userAuthenticationRequired
        }
        return false
    }
}
