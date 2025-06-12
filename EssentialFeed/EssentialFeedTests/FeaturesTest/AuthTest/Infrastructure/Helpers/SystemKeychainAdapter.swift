@preconcurrency import EssentialFeed
import Foundation

public final class SystemKeychainAdapter: @unchecked Sendable, KeychainReader, KeychainWriter {
    private let systemKeychain: SystemKeychain

    public init(systemKeychain: SystemKeychain) {
        self.systemKeychain = systemKeychain
    }

    public func load(forKey key: String) throws -> Data? {
        systemKeychain.load(forKey: key)
    }

    public func save(data: Data, forKey key: String) throws {
        let result = systemKeychain.save(data: data, forKey: key)
        if result != .success {
            throw KeychainError.unhandledError(-1)
        }
    }

    public func delete(forKey key: String) throws {
        _ = systemKeychain.delete(forKey: key)
    }
}
