import Foundation

// MARK: - DTOs para recuperación de contraseña

public struct PasswordRecoveryRequest {
    public let email: String
    public init(email: String) {
        self.email = email
    }
}

public struct PasswordRecoveryResponse: Equatable {
    public let message: String
    public init(message: String) {
        self.message = message
    }
}

public enum PasswordRecoveryError: Error, Equatable {
    case invalidEmailFormat
    case emailNotFound
    case network
    case unknown
    // Puedes añadir más errores según el backend
}

// MARK: - Protocolo de API para recuperación de contraseña

public protocol PasswordRecoveryAPI {
    func recover(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void)
}
