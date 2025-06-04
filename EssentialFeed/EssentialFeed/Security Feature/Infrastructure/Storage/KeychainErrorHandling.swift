import Foundation

public protocol KeychainErrorHandling {
    func handle(error: KeychainError, forKey key: String?, operation: String)
    func handleUnexpectedError(forKey key: String?, operation: String)
}
