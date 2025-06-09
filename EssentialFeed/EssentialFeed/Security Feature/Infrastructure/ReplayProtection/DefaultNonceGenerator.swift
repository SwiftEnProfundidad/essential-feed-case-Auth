import CryptoKit
import Foundation

public final class DefaultNonceGenerator: NonceGenerator {
    public init() {}

    public func generateNonce() -> String {
        let randomData = Data((0 ..< 16).map { _ in UInt8.random(in: 0 ... 255) })
        return randomData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
