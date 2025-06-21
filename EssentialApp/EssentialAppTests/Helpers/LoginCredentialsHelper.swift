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
            return .success(LoginResponse(user: User(name: "Test User", email: LoginCredentialsHelper.testEmail), token: Token(accessToken: "mock-token-123456", expiry: Date().addingTimeInterval(3600), refreshToken: nil)))
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
