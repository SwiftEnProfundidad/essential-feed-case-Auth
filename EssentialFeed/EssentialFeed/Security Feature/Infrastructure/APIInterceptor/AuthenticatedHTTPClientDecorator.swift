import Foundation

public enum SessionError: Error {
    case tokenRefreshFailed
}

public final class AuthenticatedHTTPClientDecorator: HTTPClient, @unchecked Sendable {
    private let client: HTTPClient
    private let tokenStore: TokenStore
    private let authUseCase: AuthUseCaseProtocol
    private let sessionManager: SessionManagerProtocol
    private let requestQueue: DispatchQueue

    public init(
        client: HTTPClient,
        tokenStore: TokenStore,
        authUseCase: AuthUseCaseProtocol,
        sessionManager: SessionManagerProtocol,
        requestQueue: DispatchQueue = DispatchQueue(
            label: "com.essentialdeveloper.auth-queue",
            qos: .userInitiated,
            attributes: .concurrent
        )
    ) {
        self.client = client
        self.tokenStore = tokenStore
        self.authUseCase = authUseCase
        self.sessionManager = sessionManager
        self.requestQueue = requestQueue
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if !requiresAuthentication(request) {
            return try await client.send(request)
        }

        let tokenResult = await tokenStore.retrieve()

        if case let .success(token) = tokenResult, token.expiry > Date() {
            do {
                let authenticatedRequest = addToken(token.accessToken, to: request)
                return try await client.send(authenticatedRequest)
            } catch {
                if isUnauthorizedError(error) {
                    return try await handleUnauthorizedError(for: request)
                }
                throw error
            }
        }

        return try await handleUnauthorizedError(for: request)
    }

    // MARK: - Private Methods

    private func requiresAuthentication(_ request: URLRequest) -> Bool {
        guard let path = request.url?.path else { return true }
        return !path.hasPrefix("/public/")
    }

    private func addToken(_ token: String, to request: URLRequest) -> URLRequest {
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func isUnauthorizedError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .userAuthenticationRequired
                || urlError.code == .userCancelledAuthentication || (urlError.errorCode == 401)
        }
        return false
    }

    private func handleUnauthorizedError(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if await sessionManager.isRefreshing {
            return try await enqueueRequestForRetry(request)
        }

        await sessionManager.startRefreshing()

        defer {
            Task { await sessionManager.endRefreshing() }
        }

        do {
            let refreshToken = try await tokenStore.retrieveRefreshToken()
            let result = await authUseCase.refreshToken(refreshToken: refreshToken)

            switch result {
            case let .success(response):
                let token = Token(accessToken: response.accessToken, expiry: response.expiry, refreshToken: response.refreshToken)
                try await tokenStore.save(token)

                let authenticatedRequest = addToken(token.accessToken, to: request)
                return try await client.send(authenticatedRequest)

            case .failure:
                await sessionManager.logout()
                throw SessionError.tokenRefreshFailed
            }
        } catch {
            await sessionManager.logout()
            throw error
        }
    }

    private func enqueueRequestForRetry(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = Task.detached(priority: .userInitiated) { [client] in
                try await client.send(request)
            }

            Task {
                do {
                    let result = try await task.value
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - TokenStore Protocol

public protocol TokenStore {
    func save(_ token: Token) async throws
    func retrieve() async -> Result<Token, Error>
    func retrieveRefreshToken() async throws -> String
    func delete() async throws
}

// MARK: - SessionManager Protocol

@MainActor
public protocol SessionManagerProtocol: AnyObject {
    var isRefreshing: Bool { get }
    func startRefreshing()
    func endRefreshing()
    func logout()
}
