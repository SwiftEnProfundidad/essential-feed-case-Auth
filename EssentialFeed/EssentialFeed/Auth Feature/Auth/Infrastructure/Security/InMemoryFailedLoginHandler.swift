import Foundation

public final class InMemoryFailedLoginHandler: FailedLoginHandlerProtocol {
    private var failedAttempts: [String: Int] = [:]
    private let maxAttempts: Int
    private let lockStatusProvider: InMemoryLoginLockStatusProvider

    public init(maxAttempts: Int = 3, lockStatusProvider: InMemoryLoginLockStatusProvider) {
        self.maxAttempts = maxAttempts
        self.lockStatusProvider = lockStatusProvider
    }

    public convenience init(maxAttempts: Int = 3) {
        let lockProvider = InMemoryLoginLockStatusProvider()
        self.init(maxAttempts: maxAttempts, lockStatusProvider: lockProvider)
    }

    public func handleFailedLogin(username: String) async {
        let currentAttempts = failedAttempts[username, default: 0] + 1
        failedAttempts[username] = currentAttempts

        if currentAttempts >= maxAttempts {
            lockStatusProvider.lockAccount(username: username)
        }
    }

    public func resetAttempts(username: String) async {
        failedAttempts.removeValue(forKey: username)
    }
}
