import Foundation

public protocol OfflineLoginStoreCleaning {
    func clearAll() async throws
}
