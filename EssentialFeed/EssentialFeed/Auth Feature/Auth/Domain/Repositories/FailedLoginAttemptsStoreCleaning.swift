import Foundation

public protocol FailedLoginAttemptsStoreCleaning {
    func clearAll() async throws
}
