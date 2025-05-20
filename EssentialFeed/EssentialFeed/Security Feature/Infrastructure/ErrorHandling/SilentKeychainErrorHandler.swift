import Foundation

public final class SilentKeychainErrorHandler: KeychainErrorHandler {
    public init() {}

    public func handle(error _: KeychainError, forKey _: String?, operation _: String) {
        // This handler intentionally does nothing with the error.
        // Errors are "silently" ignored at this level.
    }
}
