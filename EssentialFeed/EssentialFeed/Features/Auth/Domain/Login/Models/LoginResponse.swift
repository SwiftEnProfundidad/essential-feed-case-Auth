import Foundation

/// Payload devuelto por la API en caso de login satisfactorio.
public struct LoginResponse: Equatable {
    public let token: String

    public init(token: String) {
        self.token = token
    }
}
