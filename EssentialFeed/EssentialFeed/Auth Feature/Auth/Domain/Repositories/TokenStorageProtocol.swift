import Foundation

public protocol TokenStorage {
    func save(tokenBundle: Token) async throws
    func loadTokenBundle() async throws -> Token?
    func deleteTokenBundle() async throws
}
