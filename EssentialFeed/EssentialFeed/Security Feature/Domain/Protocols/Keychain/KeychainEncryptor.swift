import Foundation

public protocol KeychainEncryptor {
    func encrypt(_ data: Data) throws -> Data
    func decrypt(_ data: Data) throws -> Data
}
