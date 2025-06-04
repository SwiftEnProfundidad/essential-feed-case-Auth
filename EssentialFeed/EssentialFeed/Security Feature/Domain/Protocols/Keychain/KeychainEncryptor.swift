import Foundation

public protocol KeychainEncryptor: Sendable {
    func encrypt(_ data: Data) throws -> Data
    func decrypt(_ data: Data) throws -> Data
}
