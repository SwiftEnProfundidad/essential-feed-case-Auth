import CryptoKit
import Foundation

public final class DefaultPasswordResetTokenManager: PasswordResetTokenManager, PasswordResetTokenValidator, PasswordResetTokenUser, PasswordResetTokenCleaner {
    private let tokenReader: PasswordResetTokenReader
    private let tokenWriter: PasswordResetTokenWriter
    private let tokenUpdater: PasswordResetTokenUpdater
    private let tokenCleaner: PasswordResetTokenCleaner
    private let tokenGenerator: PasswordResetTokenGenerator
    private let expirationMinutes: Int

    public init(tokenReader: PasswordResetTokenReader, tokenWriter: PasswordResetTokenWriter, tokenUpdater: PasswordResetTokenUpdater, tokenCleaner: PasswordResetTokenCleaner, tokenGenerator: PasswordResetTokenGenerator, expirationMinutes: Int = 15) {
        self.tokenReader = tokenReader
        self.tokenWriter = tokenWriter
        self.tokenUpdater = tokenUpdater
        self.tokenCleaner = tokenCleaner
        self.tokenGenerator = tokenGenerator
        self.expirationMinutes = expirationMinutes
    }

    public func generateResetToken(for email: String) throws -> PasswordResetToken {
        guard !email.isEmpty else {
            throw PasswordResetTokenError.invalidEmail
        }

        try tokenCleaner.deleteExpiredTokens()
        try tokenCleaner.deleteTokens(for: email)

        let token = tokenGenerator.generateToken()
        let expirationDate = Date().addingTimeInterval(TimeInterval(expirationMinutes * 60))
        let resetToken = PasswordResetToken(token: token, email: email, expirationDate: expirationDate)

        try tokenWriter.saveToken(resetToken)
        return resetToken
    }

    public func validateToken(_ token: String) -> Result<PasswordResetToken, PasswordResetTokenError> {
        guard let resetToken = tokenReader.getToken(token) else {
            return .failure(.tokenNotFound)
        }

        if resetToken.isExpired {
            return .failure(.tokenExpired)
        }

        if resetToken.isUsed {
            return .failure(.tokenAlreadyUsed)
        }

        return .success(resetToken)
    }

    public func useToken(_ token: String) throws {
        let validationResult = validateToken(token)
        switch validationResult {
        case .success:
            try tokenUpdater.markTokenAsUsed(token)
        case let .failure(error):
            throw error
        }
    }

    public func deleteExpiredTokens() throws {
        try tokenCleaner.deleteExpiredTokens()
    }

    public func deleteTokens(for email: String) throws {
        try tokenCleaner.deleteTokens(for: email)
    }
}
