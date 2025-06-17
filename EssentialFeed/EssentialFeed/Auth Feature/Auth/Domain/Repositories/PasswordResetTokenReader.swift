import Foundation

public protocol PasswordResetTokenReader {
    func getToken(_ token: String) -> PasswordResetToken?
    func getTokens(for email: String) -> [PasswordResetToken]
}
