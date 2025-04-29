import Foundation

protocol SessionManager {
    var isAuthenticated: Bool { get }
}

final class RealSessionManager: SessionManager {
    private let keychain: KeychainStore
    
    init(keychain: KeychainStore) {
        self.keychain = keychain
    }
    
    var isAuthenticated: Bool {
        return keychain.get("auth_token") != nil
    }
}
