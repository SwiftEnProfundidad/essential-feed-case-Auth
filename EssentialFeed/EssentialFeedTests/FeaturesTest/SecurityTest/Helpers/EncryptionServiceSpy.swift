
import EssentialFeed
import Foundation

final class EncryptionServiceSpy: EncryptionService {
    private(set) var encryptedData: [Data] = []
    private(set) var decryptedData: [Data] = []
    var stubbedError: Error?

    func encrypt(_ data: Data) throws -> Data {
        if let error = stubbedError { throw error }
        encryptedData.append(data)
        return Data(data.reversed())
    }

    func decrypt(_ data: Data) throws -> Data {
        if let error = stubbedError { throw error }
        decryptedData.append(data)
        return Data(data.reversed())
    }
}
