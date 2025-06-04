import Foundation

public protocol KeychainReader: Sendable {
    func load(forKey key: String) throws -> Data?
}
