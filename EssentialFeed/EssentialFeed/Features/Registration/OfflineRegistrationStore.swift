import Foundation

public protocol OfflineRegistrationStore {
    func save(_ data: UserRegistrationData) async throws
}
