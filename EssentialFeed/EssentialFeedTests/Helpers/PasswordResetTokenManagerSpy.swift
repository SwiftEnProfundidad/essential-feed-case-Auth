import EssentialFeed
import Foundation

public final class PasswordResetTokenManagerSpy: PasswordResetTokenManager {
    public var generateResetTokenCallCount = 0
    public var generateResetTokenArgs: [String] = []
    public var stubbedGeneratedToken: PasswordResetToken?
    public var shouldThrowOnGenerate = false

    public init() {}

    public func generateResetToken(for email: String) throws -> PasswordResetToken {
        generateResetTokenCallCount += 1
        generateResetTokenArgs.append(email)

        if shouldThrowOnGenerate {
            throw PasswordResetTokenError.storageError
        }

        return stubbedGeneratedToken ?? PasswordResetToken(token: "default-token", email: email, expirationDate: Date().addingTimeInterval(900))
    }
}
