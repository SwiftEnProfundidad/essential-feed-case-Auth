import EssentialFeed
import Foundation
import os

final class KeychainWriterSpy: KeychainWriter, @unchecked Sendable {
    enum Message: Equatable {
        case save(data: Data, key: String)
        case delete(key: String)
    }

    private let lock = NSLock()
    private var _receivedMessages = [Message]()
    private var _saveResults: [String: Result<Void, Error>] = [:]
    private var _deleteResults: [String: Result<Void, Error>] = [:]

    var receivedMessages: [Message] {
        lock.lock()
        defer { lock.unlock() }
        return _receivedMessages
    }

    var saveCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _receivedMessages.filter { if case .save = $0 { true } else { false } }.count
    }

    var deleteCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _receivedMessages.filter { if case .delete = $0 { true } else { false } }.count
    }

    func save(data: Data, forKey key: String) throws {
        lock.lock()
        _receivedMessages.append(.save(data: data, key: key))
        let result = _saveResults[key]
        lock.unlock()

        if let result {
            if case let .failure(error) = result {
                throw error
            }
        }
    }

    func delete(forKey key: String) throws {
        lock.lock()
        _receivedMessages.append(.delete(key: key))
        let result = _deleteResults[key]
        lock.unlock()

        if let result {
            if case let .failure(error) = result {
                throw error
            }
        }
    }

    func completeSave(with error: Error, forKey key: String) {
        lock.lock()
        _saveResults[key] = .failure(error)
        lock.unlock()
    }

    func completeSaveSuccessfully(forKey key: String) {
        lock.lock()
        _saveResults[key] = .success(())
        lock.unlock()
    }

    func completeDelete(with error: Error, forKey key: String) {
        lock.lock()
        _deleteResults[key] = .failure(error)
        lock.unlock()
    }

    func completeDeleteSuccessfully(forKey key: String) {
        lock.lock()
        _deleteResults[key] = .success(())
        lock.unlock()
    }
}
