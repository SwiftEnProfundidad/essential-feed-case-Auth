import Foundation

public protocol PasswordResetTokenCleaner {
    func deleteExpiredTokens() throws
    func deleteTokens(for email: String) throws
}
