import EssentialFeed
import Foundation

public final class RefreshTokenUseCaseSpy: RefreshTokenUseCase, @unchecked Sendable {
    private let lock = NSLock()
    private var _executeCallCount = 0
    private var _stubResult: Result<Token, Error> = .failure(SessionError.tokenRefreshFailed)

    public var executeCallCount: Int {
        lock.withLock { _executeCallCount }
    }

    public var stubResult: Result<Token, Error> {
        get { lock.withLock { _stubResult } }
        set { lock.withLock { _stubResult = newValue } }
    }

    public init() {}

    public func execute() async throws -> Token {
        lock.withLock { _executeCallCount += 1 }

        let resultToReturn = lock.withLock { _stubResult }

        switch resultToReturn {
        case let .success(token):
            return token
        case let .failure(error):
            throw error
        }
    }
}
