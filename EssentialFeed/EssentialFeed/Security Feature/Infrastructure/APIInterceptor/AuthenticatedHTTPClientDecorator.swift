import Foundation

/// A decorator that adds authentication to an HTTP client.
/// It automatically handles token refresh and authentication errors.
public final class AuthenticatedHTTPClientDecorator: HTTPClient {
    private let client: HTTPClient
    private let tokenStore: TokenStore
    private let authUseCase: AuthUseCaseProtocol
    private let sessionManager: SessionManager
    private let requestQueue = DispatchQueue(label: "com.essentialdeveloper.auth-queue", qos: .userInitiated, attributes: .concurrent)

    /// Initializes the decorator with the required dependencies.
    /// - Parameters:
    ///   - client: The underlying HTTP client to decorate.
    ///   - tokenStore: The token store to manage authentication tokens.
    ///   - authUseCase: The authentication use case to handle login.
    ///   - sessionManager: The session manager to handle session state.
    public init(
        client: HTTPClient,
        tokenStore: TokenStore,
        authUseCase: AuthUseCaseProtocol,
        sessionManager: SessionManager
    ) {
        self.client = client
        self.tokenStore = tokenStore
        self.authUseCase = authUseCase
        self.sessionManager = sessionManager
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // If the request doesn't need authentication, forward it directly
        if !requiresAuthentication(request) {
            return try await client.send(request)
        }

        // Get the current token
        let tokenResult = await tokenStore.retrieve()

        // If we have a valid token, try the request with it
        if case let .success(.some(token)) = tokenResult, !token.isExpired {
            do {
                let authenticatedRequest = addToken(token.value, to: request)
                return try await client.send(authenticatedRequest)
            } catch {
                // If we get an authentication error, try to refresh the token
                if isUnauthorizedError(error) {
                    return try await handleUnauthorizedError(for: request)
                }
                throw error
            }
        }

        // If we don't have a token or it's expired, try to refresh it
        return try await handleUnauthorizedError(for: request)
    }

    // MARK: - Private Methods

    private func requiresAuthentication(_ request: URLRequest) -> Bool {
        // Skip authentication for certain paths (e.g., login, public endpoints)
        guard let url = request.url else { return true }
        return !url.path.hasPrefix("/public/")
    }

    private func addToken(_ token: String, to request: URLRequest) -> URLRequest {
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func isUnauthorizedError(_ error: Error) -> Bool {
        // Check if the error is an HTTP 401 Unauthorized
        if let urlError = error as? URLError {
            return urlError.code == .userAuthenticationRequired ||
                urlError.code == .userCancelledAuthentication ||
                (urlError.errorCode == 401)
        }
        return false
    }

    private func handleUnauthorizedError(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // Prevent multiple refresh attempts
        guard await !sessionManager.isRefreshing else {
            // If already refreshing, queue the request
            return try await withCheckedThrowingContinuation { continuation in
                requestQueue.async { [weak self] in
                    guard let self else { return }
                    Task {
                        do {
                            let result = try await self.client.send(request)
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }

        // Mark as refreshing
        await sessionManager.startRefreshing()

        do {
            // Try to refresh the token
            let refreshToken = try await tokenStore.retrieveRefreshToken()
            let result = await authUseCase.refreshToken(refreshToken)

            switch result {
            case let .success(authResponse):
                // Save the new tokens
                try await tokenStore.save(authResponse.accessToken, refreshToken: authResponse.refreshToken)

                // Retry the original request with the new token
                let authenticatedRequest = addToken(authResponse.accessToken, to: request)
                let response = try await client.send(authenticatedRequest)
                await sessionManager.endRefreshing()
                return response

            case .failure:
                // Cerrar sesión completamente
                await sessionManager.logout()
                // Limpiar credenciales
                try? await tokenStore.delete()
                throw SessionError.tokenRefreshFailed
            }
        } catch {
            await sessionManager.endRefreshing()
            throw error
        }
    }
}

// MARK: - TokenStore Protocol

public protocol TokenStore {
    func save(_ token: String, refreshToken: String) async throws
    func retrieve() async -> Result<String, Error>
    func retrieveRefreshToken() async throws -> String
    func delete() async throws
}

// MARK: - SessionManager Protocol

@MainActor
public protocol SessionManager: AnyObject {
    var isRefreshing: Bool { get }
    func startRefreshing()
    func endRefreshing()
    func logout()
}
