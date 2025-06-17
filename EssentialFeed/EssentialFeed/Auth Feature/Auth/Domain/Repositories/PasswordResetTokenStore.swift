import Foundation

public protocol PasswordResetTokenStore: PasswordResetTokenReader, PasswordResetTokenWriter, PasswordResetTokenUpdater, PasswordResetTokenCleaner {}
