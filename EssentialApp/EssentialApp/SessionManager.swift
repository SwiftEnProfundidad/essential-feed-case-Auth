import Foundation

public protocol SessionManager {
    var isAuthenticated: Bool { get }
}

public final class RealSessionManager: SessionManager {
    private let keychain: KeychainStore
    
	public init(keychain: KeychainStore) {
        self.keychain = keychain
    }
    
	public var isAuthenticated: Bool {
        return keychain.get("auth_token") != nil
    }
}
