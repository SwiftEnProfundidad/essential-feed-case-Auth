import Foundation

public protocol PasswordResetTokenWriter {
    func saveToken(_ token: PasswordResetToken) throws
}
