import Foundation

public final class InMemoryLoginLockStatusProvider: LoginLockStatusProviderProtocol {
    private var lockedAccounts: [String: Date] = [:]
    private let lockoutDuration: TimeInterval

    public init(lockoutDuration: TimeInterval = 300) { // 5 minutes default
        self.lockoutDuration = lockoutDuration
    }

    public func isAccountLocked(username: String) async -> Bool {
        guard let lockTime = lockedAccounts[username] else { return false }
        let now = Date()
        if now.timeIntervalSince(lockTime) >= lockoutDuration {
            lockedAccounts.removeValue(forKey: username)
            return false
        }
        return true
    }

    public func getRemainingBlockTime(username: String) -> TimeInterval? {
        guard let lockTime = lockedAccounts[username] else { return nil }
        let elapsed = Date().timeIntervalSince(lockTime)
        let remaining = lockoutDuration - elapsed
        return remaining > 0 ? remaining : nil
    }

    public func lockAccount(username: String) {
        lockedAccounts[username] = Date()
    }
}
