import Foundation

public final class TokenEncryptionServiceSpy {
    public private(set) var encryptedData: [Data] = []

    public func encrypt(_ data: Data) throws -> String {
        encryptedData.append(data)
        return "encrypted-token"
    }
}
