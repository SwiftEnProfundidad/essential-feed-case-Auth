import EssentialFeed
import Foundation

public actor TokenStorageSpy: TokenStorage {
    public enum Message: Equatable {
        case save(tokenBundle: Token)
        case loadTokenBundle
        case deleteTokenBundle
    }

    private var _messages = [Message]()
    private var _saveTokenBundleError: Error?
    private var _tokenBundleToReturn: Token?
    private var _loadTokenBundleError: Error?
    private var _deleteTokenBundleError: Error?
    private var _loadTokenBundleResultsQueue: [Result<Token?, Error>] = []

    public var messages: [Message] {
        _messages
    }

    public init() {}

    public func save(tokenBundle: Token) async throws {
        _messages.append(.save(tokenBundle: tokenBundle))
        if let error = _saveTokenBundleError {
            throw error
        }
    }

    public func completeSaveTokenBundleSuccessfully() {
        _saveTokenBundleError = nil
    }

    public func completeSaveTokenBundle(withError error: Error) {
        _saveTokenBundleError = error
    }

    public func stubNextLoadTokenBundle(result: Result<Token?, Error>) {
        _loadTokenBundleResultsQueue.append(result)
    }

    public func loadTokenBundle() async throws -> Token? {
        _messages.append(.loadTokenBundle)

        if !_loadTokenBundleResultsQueue.isEmpty {
            let result = _loadTokenBundleResultsQueue.removeFirst()
            switch result {
            case let .success(token):
                return token
            case let .failure(error):
                throw error
            }
        }

        if let error = _loadTokenBundleError {
            throw error
        }

        return _tokenBundleToReturn
    }

    public func completeLoad(with result: Result<Token?, Error>) async {
        switch result {
        case let .success(token):
            _tokenBundleToReturn = token
            _loadTokenBundleError = nil
        case let .failure(error):
            _loadTokenBundleError = error
            _tokenBundleToReturn = nil
        }
    }

    public func completeLoadTokenBundle(with tokenBundle: Token?) {
        _tokenBundleToReturn = tokenBundle
        _loadTokenBundleError = nil
    }

    public func completeLoadTokenBundle(withError error: Error) {
        _loadTokenBundleError = error
        _tokenBundleToReturn = nil
    }

    public func deleteTokenBundle() async throws {
        _messages.append(.deleteTokenBundle)
        if let error = _deleteTokenBundleError {
            throw error
        }
    }

    public func completeDeleteTokenBundleSuccessfully() {
        _deleteTokenBundleError = nil
    }

    public func completeDeleteTokenBundle(withError error: Error) {
        _deleteTokenBundleError = error
    }
}
