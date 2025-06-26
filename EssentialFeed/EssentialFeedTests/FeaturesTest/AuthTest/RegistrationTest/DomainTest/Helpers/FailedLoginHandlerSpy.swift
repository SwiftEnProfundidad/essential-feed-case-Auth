import EssentialFeed
import Foundation

public final class FailedLoginHandlerSpy: LoginSecurityHandlerProtocol {
    private(set) var handleFailedLoginCalls: [String] = []
    private(set) var resetAttemptsCalls: [String] = []
    private(set) var handleSuccessfulCaptchaCalls: [String] = []

    public func handleFailedLogin(username: String) async {
        handleFailedLoginCalls.append(username)
    }

    public func resetAttempts(username: String) async {
        resetAttemptsCalls.append(username)
    }

    public func handleSuccessfulCaptcha(for username: String) async {
        handleSuccessfulCaptchaCalls.append(username)
    }
}
