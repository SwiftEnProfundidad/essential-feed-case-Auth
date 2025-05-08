import Foundation

// Protocolo para guardar las credenciales de login para reintento offline
public protocol OfflineLoginStore {
    // Podríamos guardar las LoginCredentials directamente si son Codable,
    // o definir un DTO específico si es necesario.
    // Asumamos que LoginCredentials es suficiente por ahora.
    func save(credentials: LoginCredentials) async throws
}

// Asumimos que LoginCredentials es una struct definida en otra parte del Dominio/UseCase
// y es al menos Equatable y posiblemente Codable si se persiste a disco.
// public struct LoginCredentials: Equatable { ... }
