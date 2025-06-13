@preconcurrency import EssentialFeed
import Foundation

public final class PassthroughEncryptor: @unchecked Sendable, KeychainEncryptor {
    public init() {}

    public func encrypt(_ data: Data) throws -> Data {
        data
    }

    public func decrypt(_ data: Data) throws -> Data {
        data
    }
}
