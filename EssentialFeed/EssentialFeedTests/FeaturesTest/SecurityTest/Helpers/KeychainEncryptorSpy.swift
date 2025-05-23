import EssentialFeed
import Foundation

final class KeychainEncryptorSpy: KeychainEncryptor {
    enum Message: Equatable {
        case encrypt(data: Data)
        case decrypt(data: Data)
    }

    private(set) var receivedMessages = [Message]()

    private var encryptResult: Result<Data, Error>?
    private var decryptResult: Result<Data, Error>?

    func encrypt(_ data: Data) throws -> Data {
        receivedMessages.append(.encrypt(data: data))
        guard let encryptResult else {
            return data
        }
        switch encryptResult {
        case let .success(encryptedData):
            return encryptedData
        case let .failure(error):
            throw error
        }
    }

    func completeEncrypt(with data: Data) {
        encryptResult = .success(data)
    }

    func completeEncrypt(with error: Error) {
        encryptResult = .failure(error)
    }

    func decrypt(_ data: Data) throws -> Data {
        receivedMessages.append(.decrypt(data: data))
        guard let decryptResult else {
            return data
        }
        switch decryptResult {
        case let .success(decryptedData):
            return decryptedData
        case let .failure(error):
            throw error
        }
    }

    func completeDecrypt(with data: Data) {
        decryptResult = .success(data)
    }

    func completeDecrypt(with error: Error) {
        decryptResult = .failure(error)
    }
}
