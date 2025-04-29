import Foundation

protocol SessionManager {
    var isAuthenticated: Bool { get }
}

final class RealSessionManager: SessionManager {
    var isAuthenticated: Bool {
        // La fuente de verdad es Keychain
        return KeychainHelper.shared.get("auth_token") != nil
    }
}
