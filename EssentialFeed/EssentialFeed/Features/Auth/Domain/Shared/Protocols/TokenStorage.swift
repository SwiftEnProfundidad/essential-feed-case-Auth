import Foundation

public protocol TokenStorage {
    func save(_ token: Token) async throws
    func loadRefreshToken() async throws -> String? // O el tipo de token que almacenes para refrescar
    // Podrías tener más métodos, como delete, etc.
}
