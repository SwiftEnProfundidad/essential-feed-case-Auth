import Foundation

public final class DefaultLoginPersistence: LoginPersistence {
    private let tokenStorage: TokenStorage
    private let offlineStore: OfflineLoginStore
    private let config: UserLoginConfiguration

    public init(tokenStorage: TokenStorage, offlineStore: OfflineLoginStore, config: UserLoginConfiguration) {
        self.tokenStorage = tokenStorage
        self.offlineStore = offlineStore
        self.config = config
    }

    public func saveToken(_ token: Token) async throws {
        try await tokenStorage.save(tokenBundle: token)
    }

    public func saveOfflineCredentials(_ credentials: LoginCredentials) async throws {
        try await offlineStore.save(credentials: credentials)
    }

    public func saveLoginData(_ response: LoginResponse, _ credentials: LoginCredentials) async throws {
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
