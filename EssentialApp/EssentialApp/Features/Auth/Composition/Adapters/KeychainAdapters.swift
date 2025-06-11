@preconcurrency import EssentialFeed
import Foundation

// MARK: - Adapters to bridge KeychainHelper to KeychainReader/Writer

final class KeychainHelperReaderAdapter: KeychainReader, @unchecked Sendable {
    private let keychainHelper: KeychainHelper

    init(keychainHelper: KeychainHelper) {
        self.keychainHelper = keychainHelper
    }

    func load(forKey key: String) throws -> Data? {
        keychainHelper.getData(key)
    }
}

final class KeychainHelperWriterAdapter: KeychainWriter, @unchecked Sendable {
    private let keychainHelper: KeychainHelper

    init(keychainHelper: KeychainHelper) {
        self.keychainHelper = keychainHelper
    }

    func save(data: Data, forKey key: String) throws {
        let result = keychainHelper.save(data, for: key)
        switch result {
        case .success:
            return
        case let .failure(error):
            throw error
        }
    }

    func delete(forKey key: String) throws {
        let result = keychainHelper.delete(key)
        switch result {
        case .success:
            return
        case let .failure(error):
            throw error
        }
    }
}
