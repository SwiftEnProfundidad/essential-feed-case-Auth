import Foundation

public final class TokenRefreshHandler: @unchecked Sendable {
    private let refreshTokenUseCase: RefreshTokenUseCase
    private let tokenStorage: TokenWriter

    private var refreshTask: Task<Token, Error>?
    private let accessQueue = DispatchQueue(label: "TokenRefreshHandler.access", attributes: .concurrent)

    public init(refreshTokenUseCase: RefreshTokenUseCase, tokenStorage: TokenWriter) {
        self.refreshTokenUseCase = refreshTokenUseCase
        self.tokenStorage = tokenStorage
    }

    func getRefreshedToken() async throws -> Token {
        let task: Task<Token, Error> = accessQueue.sync {
            if let existingTask = refreshTask {
                return existingTask
            }

            let newTask = Task<Token, Error> {
                defer {
                    self.accessQueue.async(flags: .barrier) {
                        self.refreshTask = nil
                    }
                }

                do {
                    let token = try await self.refreshTokenUseCase.execute()
                    try await self.tokenStorage.save(tokenBundle: token)
                    return token
                } catch {
                    throw SessionError.tokenRefreshFailed
                }
            }

            refreshTask = newTask
            return newTask
        }

        return try await task.value
    }
}
