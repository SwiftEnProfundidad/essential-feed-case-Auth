import EssentialFeed
import Foundation

class TokenStorageSpy: TokenStorage {
    private(set) var saveTokenBundleCalls: [Token] = []
    private(set) var loadTokenBundleCalls: Int = 0
    private(set) var deleteTokenBundleCalls: Int = 0

    var stubbedToken: Token?
    var saveError: Error?
    var loadError: Error?
    var deleteError: Error?

    func save(tokenBundle: Token) async throws {
        saveTokenBundleCalls.append(tokenBundle)
        if let error = saveError {
            throw error
        }
    }

    func loadTokenBundle() async throws -> Token? {
        loadTokenBundleCalls += 1
        if let error = loadError {
            throw error
        }
        return stubbedToken
    }

    func deleteTokenBundle() async throws {
        deleteTokenBundleCalls += 1
        if let error = deleteError {
            throw error
        }
    }
}
