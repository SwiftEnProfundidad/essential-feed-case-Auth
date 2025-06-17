import EssentialFeed
import Foundation
import os

final class KeychainReaderSpy: KeychainReader, @unchecked Sendable {
    enum Message: Equatable {
        case load(key: String)
    }

    private let lock = NSLock()
    private var _receivedMessages = [Message]()
    private var _loadResults: [String: Result<Data?, Error>] = [:]

    var receivedMessages: [Message] {
        lock.lock()
        defer { lock.unlock() }
        return _receivedMessages
    }

    func load(forKey key: String) throws -> Data? {
        lock.lock()
        _receivedMessages.append(.load(key: key))
        let result = _loadResults[key]
        lock.unlock()

        if let result {
            switch result {
            case let .success(data):
                return data
            case let .failure(error):
                throw error
            }
        }

        return nil
    }

    func completeLoad(with data: Data?, forKey key: String) {
        lock.lock()
        _loadResults[key] = .success(data)
        lock.unlock()
    }

    func completeLoad(with error: Error, forKey key: String) {
        lock.lock()
        _loadResults[key] = .failure(error)
        lock.unlock()
    }
}
