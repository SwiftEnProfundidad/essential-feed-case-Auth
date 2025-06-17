import CryptoKit
import Foundation

public protocol PasswordResetTokenGenerator {
    func generateToken() -> String
}

public final class CryptoKitPasswordResetTokenGenerator: PasswordResetTokenGenerator {
    public init() {}

    public func generateToken() -> String {
        let data = Data((0 ..< 32).map { _ in UInt8.random(in: 0 ... 255) })
        return data.base64URLEncodedString()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
