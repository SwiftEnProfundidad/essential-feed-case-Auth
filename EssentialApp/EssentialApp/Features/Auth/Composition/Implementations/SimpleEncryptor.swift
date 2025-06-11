import CryptoKit
@preconcurrency import EssentialFeed
import Foundation

// MARK: - Simple Encryptor (no-op for now)

final class SimpleEncryptor: KeychainEncryptor, @unchecked Sendable {
    func encrypt(_ data: Data) throws -> Data {
        data
    }

    func decrypt(_ data: Data) throws -> Data {
        data
    }
}
