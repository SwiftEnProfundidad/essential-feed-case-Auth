import EssentialFeed
import Foundation

public final class FailedLoginHandlerSpy: FailedLoginHandlerProtocol {
    private(set) var handleFailedLoginCalls: [String] = []
    private(set) var resetAttemptsCalls: [String] = []

    public func handleFailedLogin(username: String) async {
        handleFailedLoginCalls.append(username)
    }

    public func resetAttempts(username: String) async {
        resetAttemptsCalls.append(username)
    }
}
