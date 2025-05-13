import Foundation

public protocol TokenStorage {
    func save(_ token: Token) async throws
    func loadRefreshToken() async throws -> String?
}
