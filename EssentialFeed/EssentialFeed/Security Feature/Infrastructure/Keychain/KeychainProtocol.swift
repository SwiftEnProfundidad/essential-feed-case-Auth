import Foundation

public enum KeychainSaveResult: Equatable {
    case success
    case duplicateItem
    case failure
}

public protocol KeychainSavable {
    func save(data: Data, forKey key: String) -> KeychainSaveResult
    func load(forKey key: String) -> Data?
}

public protocol KeychainDeletable {
    func delete(forKey key: String) -> Bool
}

public protocol KeychainUpdatable {
    func update(data: Data, forKey key: String) -> OSStatus
}

public protocol KeychainFull: KeychainSavable {
    func update(data: Data, forKey key: String) -> OSStatus
    func delete(forKey key: String) -> Bool
    func load(forKey key: String) -> Data?
}

public typealias KeychainProtocolWithDelete = KeychainFull
public typealias KeychainProtocol = KeychainSavable
