import EssentialFeed
import Foundation

public class InMemoryTokenStorage: TokenStorage {
    private var token: Token?

    public init() {}

    public func loadTokenBundle() async throws -> Token? {
        print("📱 InMemoryTokenStorage: Loading token - \(token?.accessToken ?? "nil")")
        return token
    }

    public func save(tokenBundle: Token) async throws {
        self.token = tokenBundle
        print("📱 InMemoryTokenStorage: Saved token - \(tokenBundle.accessToken)")
    }

    public func deleteTokenBundle() async throws {
        token = nil
        print("📱 InMemoryTokenStorage: Deleted token")
    }
}
