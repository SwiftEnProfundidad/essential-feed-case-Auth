import Foundation

public protocol LoginLockStatusProviderProtocol {
    func isAccountLocked(username: String) async -> Bool
    func getRemainingBlockTime(username: String) -> TimeInterval?
}
