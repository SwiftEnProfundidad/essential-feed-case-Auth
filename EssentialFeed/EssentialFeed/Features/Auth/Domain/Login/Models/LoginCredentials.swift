import Foundation

/// Datos que necesita la API para autenticar al usuario.
public struct LoginCredentials: Equatable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}
