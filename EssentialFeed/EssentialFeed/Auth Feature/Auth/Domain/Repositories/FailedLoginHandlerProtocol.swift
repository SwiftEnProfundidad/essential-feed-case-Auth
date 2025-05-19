import Foundation

public protocol FailedLoginHandlerProtocol {
    func handleFailedLogin(username: String) async
    func resetAttempts(username: String) async
}
