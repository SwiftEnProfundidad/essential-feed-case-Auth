import Foundation

public actor TokenRefreshHandler {
    private let refreshTokenUseCase: RefreshTokenUseCase
    private let tokenStorage: TokenWriter

    private var refreshTask: Task<Token, Error>?

    public init(refreshTokenUseCase: RefreshTokenUseCase, tokenStorage: TokenWriter) {
        self.refreshTokenUseCase = refreshTokenUseCase
        self.tokenStorage = tokenStorage
    }

    func getRefreshedToken() async throws -> Token {
        if let existingTask = refreshTask {
            return try await existingTask.value
        }

        let newTask = Task { () -> Token in
            defer {
                self.refreshTask = nil
            }
            let token = try await refreshTokenUseCase.execute()
            try await tokenStorage.save(tokenBundle: token)
            return token
        }

        self.refreshTask = newTask
        return try await newTask.value
    }
}
