import Foundation

public protocol PasswordResetTokenValidator {
    func validateToken(_ token: String) -> Result<PasswordResetToken, PasswordResetTokenError>
}

public protocol PasswordResetTokenUser {
    func useToken(_ token: String) throws
}

public protocol PasswordResetTokenManager {
    func generateResetToken(for email: String) throws -> PasswordResetToken
}
