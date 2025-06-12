import Foundation

public protocol TokenRefreshCoordinator {
    func getRefreshedToken() async throws -> Token
}
