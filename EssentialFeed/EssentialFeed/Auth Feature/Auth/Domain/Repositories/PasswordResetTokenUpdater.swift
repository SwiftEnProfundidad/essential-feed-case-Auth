import Foundation

public protocol PasswordResetTokenUpdater {
    func markTokenAsUsed(_ token: String) throws
}
