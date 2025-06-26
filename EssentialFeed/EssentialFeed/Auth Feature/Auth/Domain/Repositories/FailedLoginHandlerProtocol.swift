import Foundation

public protocol FailedLoginHandlerProtocol {
    func handleFailedLogin(username: String) async
    func resetAttempts(username: String) async
}

public protocol CaptchaSuccessHandlerProtocol {
    func handleSuccessfulCaptcha(for username: String) async
}

public protocol LoginSecurityHandlerProtocol: FailedLoginHandlerProtocol, CaptchaSuccessHandlerProtocol {}
