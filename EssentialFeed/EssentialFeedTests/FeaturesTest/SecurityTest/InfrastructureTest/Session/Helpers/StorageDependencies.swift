@preconcurrency import EssentialFeed

public struct StorageDependencies {
    public let tokenStorage: KeychainTokenStore
    public let offlineLoginStore: InMemoryOfflineLoginStoreAdapter
    public let offlineRegistrationStore: InMemoryOfflineRegistrationStoreSpy
    public let failedLoginStore: InMemoryFailedLoginAttemptsStoreAdapter
    public let sessionUserDefaults: SessionUserDefaultsManager

    public init(tokenStorage: KeychainTokenStore, offlineLoginStore: InMemoryOfflineLoginStoreAdapter, offlineRegistrationStore: InMemoryOfflineRegistrationStoreSpy, failedLoginStore: InMemoryFailedLoginAttemptsStoreAdapter, sessionUserDefaults: SessionUserDefaultsManager) {
        self.tokenStorage = tokenStorage
        self.offlineLoginStore = offlineLoginStore
        self.offlineRegistrationStore = offlineRegistrationStore
        self.failedLoginStore = failedLoginStore
        self.sessionUserDefaults = sessionUserDefaults
    }
}
