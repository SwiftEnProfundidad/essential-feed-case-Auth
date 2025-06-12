import Foundation

public protocol OfflineRegistrationStoreCleaning {
    func clearAll() async throws
}
