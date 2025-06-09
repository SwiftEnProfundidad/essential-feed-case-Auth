import EssentialFeed
import Foundation

public final class LoginLockStatusProviderSpy: LoginLockStatusProviderProtocol {
    var lockedUsers: Set<String> = []
    var remainingTime: TimeInterval = 0

    public func isAccountLocked(username: String) async -> Bool {
        lockedUsers.contains(username)
    }

    public func getRemainingBlockTime(username: String) -> TimeInterval? {
        lockedUsers.contains(username) ? remainingTime : nil
    }
}
