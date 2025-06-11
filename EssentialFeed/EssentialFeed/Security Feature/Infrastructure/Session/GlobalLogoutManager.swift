import Foundation

public final class GlobalLogoutManager: SessionLogoutManager {
    private let tokenStorage: TokenStorage
    private let offlineLoginStore: OfflineLoginStoreCleaning
    private let offlineRegistrationStore: OfflineRegistrationStoreCleaning
    private let failedLoginAttemptsStore: FailedLoginAttemptsStoreCleaning
    private let sessionUserDefaults: SessionUserDefaultsCleaning

    public init(tokenStorage: TokenStorage, offlineLoginStore: OfflineLoginStoreCleaning, offlineRegistrationStore: OfflineRegistrationStoreCleaning, failedLoginAttemptsStore: FailedLoginAttemptsStoreCleaning, sessionUserDefaults: SessionUserDefaultsCleaning) {
        self.tokenStorage = tokenStorage
        self.offlineLoginStore = offlineLoginStore
        self.offlineRegistrationStore = offlineRegistrationStore
        self.failedLoginAttemptsStore = failedLoginAttemptsStore
        self.sessionUserDefaults = sessionUserDefaults
    }

    public func performGlobalLogout() async throws {
        try await tokenStorage.deleteTokenBundle()
        try await offlineLoginStore.clearAll()
        try await offlineRegistrationStore.clearAll()
        try await failedLoginAttemptsStore.clearAll()
        try await sessionUserDefaults.clearSessionData()
        // Aquí podríamos añadir más limpieza si fuera necesario:
        // - Limpiar cache de usuario
        // - Notificar a otros componentes del logout
    }
}
