
import Foundation

public final class KeychainSessionManager: SessionManager {
    private let keychain: KeychainStore

    public init(keychain: KeychainStore) {
        self.keychain = keychain
    }

    public var isAuthenticated: Bool {
        keychain.get("auth_token") != nil
    }
}
