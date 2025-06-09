import Foundation

public protocol SessionLogoutManager {
    func performGlobalLogout() async throws
}
