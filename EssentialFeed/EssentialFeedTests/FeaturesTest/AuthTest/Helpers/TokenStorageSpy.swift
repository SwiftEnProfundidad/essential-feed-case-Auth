import EssentialFeed
import Foundation

public final class TokenStorageSpy: TokenStorage {
    public enum Message: Equatable {
        case save(Token)
        case loadRefreshToken
    }

    public private(set) var messages = [Message]()

    public var saveTokenError: Error?

    public func save(_ token: Token) async throws {
        messages.append(.save(token))
        if let error = saveTokenError {
            throw error
        }
    }

    public func completeSaveSuccessfully() {
        saveTokenError = nil
    }

    public func completeSave(withError error: Error) {
        saveTokenError = error
    }

    public var refreshTokenToReturn: String?
    public var loadRefreshTokenError: Error?

    public func loadRefreshToken() async throws -> String? {
        messages.append(.loadRefreshToken)
        if let error = loadRefreshTokenError {
            throw error
        }
        return refreshTokenToReturn
    }

    public func completeLoadRefreshToken(with token: String?) {
        refreshTokenToReturn = token
        loadRefreshTokenError = nil
    }

    public func completeLoadRefreshToken(withError error: Error) {
        loadRefreshTokenError = error
        refreshTokenToReturn = nil
    }
}
