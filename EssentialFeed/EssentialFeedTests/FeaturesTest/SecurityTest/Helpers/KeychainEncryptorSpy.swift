import EssentialFeed
import Foundation
import os

final class KeychainEncryptorSpy: KeychainEncryptor, @unchecked Sendable {
    enum Message: Equatable {
        case encrypt(data: Data)
        case decrypt(data: Data)
    }

    private let lock = NSLock()
    private var _receivedMessages = [Message]()
    private var _encryptResult: Result<Data, Error>?
    private var _decryptResult: Result<Data, Error>?

    var receivedMessages: [Message] {
        lock.lock()
        defer { lock.unlock() }
        return _receivedMessages
    }

    var encryptCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _receivedMessages.filter { if case .encrypt = $0 { true } else { false } }.count
    }

    var decryptCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _receivedMessages.filter { if case .decrypt = $0 { true } else { false } }.count
    }

    var encryptedData: [Data] {
        lock.lock()
        defer { lock.unlock() }
        return _receivedMessages.compactMap { if case let .encrypt(data) = $0 { data } else { nil } }
    }

    func encrypt(_ data: Data) throws -> Data {
        lock.lock()
        _receivedMessages.append(.encrypt(data: data))
        let result = _encryptResult
        lock.unlock()

        guard let result else {
            return data
        }

        switch result {
        case let .success(encryptedData):
            return encryptedData
        case let .failure(error):
            throw error
        }
    }

    func decrypt(_ data: Data) throws -> Data {
        lock.lock()
        _receivedMessages.append(.decrypt(data: data))
        let result = _decryptResult
        lock.unlock()

        guard let result else {
            return data
        }

        switch result {
        case let .success(decryptedData):
            return decryptedData
        case let .failure(error):
            throw error
        }
    }

    func completeEncrypt(with data: Data) {
        lock.lock()
        _encryptResult = .success(data)
        lock.unlock()
    }

    func completeEncrypt(with error: Error) {
        lock.lock()
        _encryptResult = .failure(error)
        lock.unlock()
    }

    func completeDecrypt(with data: Data) {
        lock.lock()
        _decryptResult = .success(data)
        lock.unlock()
    }

    func completeDecrypt(with error: Error) {
        lock.lock()
        _decryptResult = .failure(error)
        lock.unlock()
    }
}
