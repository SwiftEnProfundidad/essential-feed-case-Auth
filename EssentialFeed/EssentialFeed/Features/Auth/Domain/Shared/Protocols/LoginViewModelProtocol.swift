
import Foundation

public protocol LoginViewModelProtocol: AnyObject {
    var username: String { get set }
    var password: String { get set }
    var errorMessage: String? { get set }
    var loginSuccess: Bool { get set }
    var isLoginBlocked: Bool { get set }
    func login() async
    func unlockAfterRecovery() async
}
