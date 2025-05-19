import Foundation

public protocol LoginLockStatusProviderProtocol {
    func isAccountLocked(username: String) -> Bool
    func getRemainingBlockTime(username: String) -> TimeInterval?
}
