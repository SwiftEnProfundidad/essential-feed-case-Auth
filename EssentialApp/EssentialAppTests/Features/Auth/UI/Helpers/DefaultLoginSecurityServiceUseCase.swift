import EssentialFeed
import Foundation

class DefaultLoginSecurityServiceUseCase: LoginLockStatusProviderProtocol, FailedLoginHandlerProtocol {
    private let lockStatusProvider: LoginLockStatusProviderSpy
    private let failedLoginHandler: FailedLoginHandlerSpy

    init(lockStatusProvider: LoginLockStatusProviderSpy, failedLoginHandler: FailedLoginHandlerSpy) {
        self.lockStatusProvider = lockStatusProvider
        self.failedLoginHandler = failedLoginHandler
    }

    func isAccountLocked(username: String) async -> Bool {
        await lockStatusProvider.isAccountLocked(username: username)
    }

    func getRemainingBlockTime(username: String) -> TimeInterval? {
        lockStatusProvider.getRemainingBlockTime(username: username)
    }

    func resetAttempts(username: String) async {
        await failedLoginHandler.resetAttempts(username: username)
    }

    func handleFailedLogin(username: String) async {
        await failedLoginHandler.handleFailedLogin(username: username)
    }
}
