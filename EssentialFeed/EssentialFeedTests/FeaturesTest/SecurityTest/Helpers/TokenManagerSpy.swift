import EssentialFeed
import Foundation

public final class TokenManagerSpy: TokenManager {
    public enum Message: Equatable {
        case getValidToken
        case refreshTokenIfNeeded
    }

    public private(set) var messages: [Message] = []
    public private(set) var refreshTokenCalls: Int = 0

    public var validTokenResult: Result<Token, Error> = .failure(SessionError.tokenRetrievalFailed)
    public var refreshedTokenResult: Result<Token, Error> = .failure(SessionError.tokenRefreshFailed)

    public init() {}

    public func getValidToken() async throws -> Token {
        messages.append(.getValidToken)
        return try validTokenResult.get()
    }

    public func refreshTokenIfNeeded() async throws -> Token {
        messages.append(.refreshTokenIfNeeded)
        refreshTokenCalls += 1
        return try refreshedTokenResult.get()
    }
}
