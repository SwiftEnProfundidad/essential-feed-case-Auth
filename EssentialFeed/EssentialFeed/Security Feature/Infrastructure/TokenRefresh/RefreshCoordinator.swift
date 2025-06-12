import Foundation

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
