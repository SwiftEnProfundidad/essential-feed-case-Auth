import Foundation

public protocol LoginPersistence {
    func saveToken(_ token: Token) async throws
    func saveOfflineCredentials(_ credentials: LoginCredentials) async throws
    func saveLoginData(_ response: LoginResponse, _ credentials: LoginCredentials) async throws
}
