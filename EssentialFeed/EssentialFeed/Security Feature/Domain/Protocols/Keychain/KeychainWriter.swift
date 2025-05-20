import Foundation

public protocol KeychainWriter {
    func save(data: Data, forKey key: String) throws
    func delete(forKey key: String) throws
}
