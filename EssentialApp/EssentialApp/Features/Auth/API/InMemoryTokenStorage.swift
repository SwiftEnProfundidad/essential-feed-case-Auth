import EssentialFeed
import Foundation

class InMemoryTokenStorage: TokenStorage {
    private var token: Token?

    func loadTokenBundle() async throws -> Token? {
        return token
    }

    func save(tokenBundle: Token) async throws {
        self.token = tokenBundle
    }

    func deleteTokenBundle() async throws {
        token = nil
    }
}
