import EssentialFeed // para el protocolo EncryptionService
import Foundation

public final class EncryptionServiceDataSpy: EncryptionService {
    public private(set) var encryptedData: [Data] = []
    public private(set) var decryptedData: [Data] = []

    public var stubbedError: Error?

    public init() {}

    // MARK: - EncryptionService

    public func encrypt(_ data: Data) throws -> Data {
        if let error = stubbedError { throw error }
        encryptedData.append(data)
        return Data(data.reversed()) // simple “cifrado” fake
    }

    public func decrypt(_ data: Data) throws -> Data {
        if let error = stubbedError { throw error }
        decryptedData.append(data)
        return Data(data.reversed()) // “descifrado” fake
    }
}
