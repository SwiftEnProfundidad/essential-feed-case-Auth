import Foundation

public final class DefaultLoginPersistence: LoginPersistence {
    private let tokenStorage: TokenStorage
    private let offlineStore: OfflineLoginStore

    public init(tokenStorage: TokenStorage, offlineStore: OfflineLoginStore) {
        self.tokenStorage = tokenStorage
        self.offlineStore = offlineStore
    }

    public func saveToken(_ token: Token) async throws {
        try await tokenStorage.save(tokenBundle: token)
    }

    public func saveOfflineCredentials(_ credentials: LoginCredentials) async throws {
        try await offlineStore.save(credentials: credentials)
    }
}
