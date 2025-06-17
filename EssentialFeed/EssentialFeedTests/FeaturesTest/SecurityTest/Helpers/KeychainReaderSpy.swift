import EssentialFeed
import Foundation
import os

final class KeychainReaderSpy: KeychainReader, @unchecked Sendable {
    enum Message: Equatable {
        case load(key: String)
    }

    private let lock = OSAllocatedUnfairLock()
    private var _receivedMessages = [Message]()
    private var _loadResults: [String: Result<Data?, Error>] = [:]

    var receivedMessages: [Message] {
        lock.withLock { _receivedMessages }
    }

    func load(forKey key: String) throws -> Data? {
        let result = lock.withLock { () -> Result<Data?, Error>? in
            _receivedMessages.append(.load(key: key))
            return _loadResults[key]
        }

        guard let result else {
            return nil
        }

        switch result {
        case let .success(data):
            return data
        case let .failure(error):
            throw error
        }
    }

    func completeLoad(with data: Data?, forKey key: String) {
        lock.withLock {
            _loadResults[key] = .success(data)
        }
    }

    func completeLoad(with error: Error, forKey key: String) {
        lock.withLock {
            _loadResults[key] = .failure(error)
        }
    }
}
