import EssentialFeed
import Foundation

enum LoginCredentialsHelper {
    static let testEmail = "test@example.com"
    static let testPassword = "Password123!"

    static var validCredentials: LoginCredentials {
        return LoginCredentials(
            email: testEmail,
            password: testPassword
        )
    }
}

class MockLoginAPI: UserLoginAPI {
    func login(with credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
        if credentials.email == LoginCredentialsHelper.testEmail &&
            credentials.password == LoginCredentialsHelper.testPassword
        {
            return .success(LoginResponse(token: "mock-token-123456"))
        }

        return .failure(.invalidCredentials)
    }
}

extension MockLoginAPI {
    static func getInfoMessage() -> String {
        return """
        ** MODO PRUEBA ACTIVO **
        Usuario: \(LoginCredentialsHelper.testEmail)
        Contraseña: \(LoginCredentialsHelper.testPassword)

        Después de 3 intentos fallidos, la cuenta se bloqueará.
        """
    }
}
