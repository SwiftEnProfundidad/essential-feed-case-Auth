import EssentialFeed
import Foundation
import os

final class KeychainEncryptorSpy: KeychainEncryptor, @unchecked Sendable {
    enum Message: Equatable {
        case encrypt(data: Data)
        case decrypt(data: Data)
    }

    private let lock = OSAllocatedUnfairLock()
    private var _receivedMessages = [Message]()
    private var _encryptResult: Result<Data, Error>?
    private var _decryptResult: Result<Data, Error>?

    var receivedMessages: [Message] {
        lock.withLock { _receivedMessages }
    }

    var encryptCallCount: Int {
        lock.withLock {
            _receivedMessages.filter { if case .encrypt = $0 { true } else { false } }.count
        }
    }

    var decryptCallCount: Int {
        lock.withLock {
            _receivedMessages.filter { if case .decrypt = $0 { true } else { false } }.count
        }
    }

    var encryptedData: [Data] {
        lock.withLock {
            _receivedMessages.compactMap { if case let .encrypt(data) = $0 { data } else { nil } }
        }
    }

    func encrypt(_ data: Data) throws -> Data {
        let result = lock.withLock { () -> Result<Data, Error>? in
            _receivedMessages.append(.encrypt(data: data))
            return _encryptResult
        }

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
        let result = lock.withLock { () -> Result<Data, Error>? in
            _receivedMessages.append(.decrypt(data: data))
            return _decryptResult
        }

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
        lock.withLock {
            _encryptResult = .success(data)
        }
    }

    func completeEncrypt(with error: Error) {
        lock.withLock {
            _encryptResult = .failure(error)
        }
    }

    func completeDecrypt(with data: Data) {
        lock.withLock {
            _decryptResult = .success(data)
        }
    }

    func completeDecrypt(with error: Error) {
        lock.withLock {
            _decryptResult = .failure(error)
        }
    }
}
