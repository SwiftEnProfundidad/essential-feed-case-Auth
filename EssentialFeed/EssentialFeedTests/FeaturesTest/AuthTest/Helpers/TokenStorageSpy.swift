import EssentialFeed
import Foundation

public final class TokenStorageSpy: TokenStorage {
    public enum Message: Equatable {
        case save(tokenBundle: Token)
        case loadTokenBundle
        case deleteTokenBundle
    }

    public private(set) var messages = [Message]()

    public var saveTokenBundleError: Error?

    public func save(tokenBundle: Token) async throws {
        messages.append(.save(tokenBundle: tokenBundle))
        if let error = saveTokenBundleError {
            throw error
        }
    }

    public func completeSaveTokenBundleSuccessfully() {
        saveTokenBundleError = nil
    }

    public func completeSaveTokenBundle(withError error: Error) {
        saveTokenBundleError = error
    }

    public var tokenBundleToReturn: Token?
    public var loadTokenBundleError: Error?

    public func loadTokenBundle() async throws -> Token? {
        messages.append(.loadTokenBundle)
        if let error = loadTokenBundleError {
            throw error
        }
        return tokenBundleToReturn
    }

    public func completeLoadTokenBundle(with tokenBundle: Token?) {
        tokenBundleToReturn = tokenBundle
        loadTokenBundleError = nil
    }

    public func completeLoadTokenBundle(withError error: Error) {
        loadTokenBundleError = error
        tokenBundleToReturn = nil
    }

    public var deleteTokenBundleError: Error?

    public func deleteTokenBundle() async throws {
        messages.append(.deleteTokenBundle)
        if let error = deleteTokenBundleError {
            throw error
        }
    }

    public func completeDeleteTokenBundleSuccessfully() {
        deleteTokenBundleError = nil
    }

    public func completeDeleteTokenBundle(withError error: Error) {
        deleteTokenBundleError = error
    }
}
