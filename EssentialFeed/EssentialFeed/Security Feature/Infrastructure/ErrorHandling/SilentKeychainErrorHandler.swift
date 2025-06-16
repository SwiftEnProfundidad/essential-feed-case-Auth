import Foundation

public final class SilentKeychainErrorHandler: KeychainErrorHandler {
    public init() {}

    public func handle(error _: KeychainError, forKey _: String?, operation _: String) {}

    public func handleUnexpectedError(forKey _: String?, operation _: String) {}
}
