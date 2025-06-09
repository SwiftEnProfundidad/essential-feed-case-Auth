import EssentialFeed
import Foundation

class LoginPersistenceSpy: LoginPersistence {
    private let tokenStorage: TokenStorageSpy
    private let offlineStore: OfflineLoginStoreSpy
    private let config: UserLoginConfiguration

    private(set) var saveTokenCalls: [Token] = []
    private(set) var saveOfflineCredentialsCalls: [LoginCredentials] = []
    private(set) var saveLoginDataCalls: [(LoginResponse, LoginCredentials)] = []

    init(tokenStorage: TokenStorageSpy, offlineStore: OfflineLoginStoreSpy, config: UserLoginConfiguration) {
        self.tokenStorage = tokenStorage
        self.offlineStore = offlineStore
        self.config = config
    }

    func saveToken(_ token: Token) async throws {
        saveTokenCalls.append(token)
        try await tokenStorage.save(tokenBundle: token)
    }

    func saveOfflineCredentials(_ credentials: LoginCredentials) async throws {
        saveOfflineCredentialsCalls.append(credentials)
        try await offlineStore.save(credentials: credentials)
    }

    func saveLoginData(_ response: LoginResponse, _ credentials: LoginCredentials) async throws {
        saveLoginDataCalls.append((response, credentials))
        let expiryDate = Date().addingTimeInterval(config.tokenDuration)
        let tokenToStore = Token(
            accessToken: response.token,
            expiry: expiryDate,
            refreshToken: nil
        )
        try await saveToken(tokenToStore)
        try? await saveOfflineCredentials(credentials)
    }
}
