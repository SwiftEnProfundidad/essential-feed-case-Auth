import Foundation

public protocol OfflineLoginStore {
    func save(credentials: LoginCredentials) async throws
}
