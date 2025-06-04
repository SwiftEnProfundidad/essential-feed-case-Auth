import Foundation

public protocol TokenManager {
    func getValidToken() async throws -> Token
    func refreshTokenIfNeeded() async throws -> Token
}

public final class DefaultTokenManager: TokenManager {
    private let tokenStore: TokenStore
    private let authUseCase: AuthUseCaseProtocol
    private let sessionManager: SessionManagerProtocol

    public init(
        tokenStore: TokenStore,
        authUseCase: AuthUseCaseProtocol,
        sessionManager: SessionManagerProtocol
    ) {
        self.tokenStore = tokenStore
        self.authUseCase = authUseCase
        self.sessionManager = sessionManager
    }

    public func getValidToken() async throws -> Token {
        let tokenResult = await tokenStore.retrieve()

        switch tokenResult {
        case let .success(token):
            if token.expiry > Date() {
                return token
            }
            return try await refreshTokenIfNeeded()
        case .failure:
            throw SessionError.tokenRetrievalFailed
        }
    }

    public func refreshTokenIfNeeded() async throws -> Token {
        if await sessionManager.isRefreshing {
            return try await waitForRefreshCompletion()
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
                let token = Token(
                    accessToken: response.accessToken,
                    expiry: response.expiry,
                    refreshToken: response.refreshToken
                )
                try await tokenStore.save(token)
                return token

            case .failure:
                await sessionManager.logout()
                throw SessionError.tokenRefreshFailed
            }
        } catch {
            await sessionManager.logout()
            throw error
        }
    }

    private func waitForRefreshCompletion() async throws -> Token {
        while await sessionManager.isRefreshing {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return try await getValidToken()
    }
}
