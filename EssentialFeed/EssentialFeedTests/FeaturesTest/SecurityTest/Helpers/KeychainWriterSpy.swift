import EssentialFeed
import Foundation
import os

final class KeychainWriterSpy: KeychainWriter, @unchecked Sendable {
    enum Message: Equatable {
        case save(data: Data, key: String)
        case delete(key: String)
    }

    private let lock = OSAllocatedUnfairLock()
    private var _receivedMessages = [Message]()
    private var _saveResults: [String: Result<Void, Error>] = [:]
    private var _deleteResults: [String: Result<Void, Error>] = [:]

    var receivedMessages: [Message] {
        lock.withLock { _receivedMessages }
    }

    var saveCallCount: Int {
        lock.withLock {
            _receivedMessages.filter { if case .save = $0 { true } else { false } }.count
        }
    }

    var deleteCallCount: Int {
        lock.withLock {
            _receivedMessages.filter { if case .delete = $0 { true } else { false } }.count
        }
    }

    func save(data: Data, forKey key: String) throws {
        let result = lock.withLock { () -> Result<Void, Error>? in
            _receivedMessages.append(.save(data: data, key: key))
            return _saveResults[key]
        }

        if let result {
            if case let .failure(error) = result {
                throw error
            }
        }
    }

    func delete(forKey key: String) throws {
        let result = lock.withLock { () -> Result<Void, Error>? in
            _receivedMessages.append(.delete(key: key))
            return _deleteResults[key]
        }

        if let result {
            if case let .failure(error) = result {
                throw error
            }
        }
    }

    func completeSave(with error: Error, forKey key: String) {
        lock.withLock {
            _saveResults[key] = .failure(error)
        }
    }

    func completeSaveSuccessfully(forKey key: String) {
        lock.withLock {
            _saveResults[key] = .success(())
        }
    }

    func completeDelete(with error: Error, forKey key: String) {
        lock.withLock {
            _deleteResults[key] = .failure(error)
        }
    }

    func completeDeleteSuccessfully(forKey key: String) {
        lock.withLock {
            _deleteResults[key] = .success(())
        }
    }
}
