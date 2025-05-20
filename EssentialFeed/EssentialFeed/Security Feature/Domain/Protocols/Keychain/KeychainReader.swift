import Foundation

public protocol KeychainReader {
    func load(forKey key: String) throws -> Data?
}
