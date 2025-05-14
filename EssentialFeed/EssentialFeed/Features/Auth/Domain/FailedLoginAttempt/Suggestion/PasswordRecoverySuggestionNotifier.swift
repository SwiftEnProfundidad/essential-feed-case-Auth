
import Foundation

public protocol PasswordRecoverySuggestionNotifier {
    func suggestPasswordRecovery(for email: String)
}
