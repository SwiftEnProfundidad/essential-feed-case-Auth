import Foundation

public final class GlobalLogoutManager: SessionLogoutManager {
    private let tokenStorage: TokenStorage
    private let offlineLoginStore: OfflineLoginStoreCleaning
    private let offlineRegistrationStore: OfflineRegistrationStoreCleaning

    public init(tokenStorage: TokenStorage, offlineLoginStore: OfflineLoginStoreCleaning, offlineRegistrationStore: OfflineRegistrationStoreCleaning) {
        self.tokenStorage = tokenStorage
        self.offlineLoginStore = offlineLoginStore
        self.offlineRegistrationStore = offlineRegistrationStore
    }

    public func performGlobalLogout() async throws {
        try await tokenStorage.deleteTokenBundle()
        try await offlineLoginStore.clearAll()
        try await offlineRegistrationStore.clearAll()
        // Aquí podríamos añadir más limpieza si fuera necesario:
        // - Limpiar cache de usuario
        // - Limpiar UserDefaults relacionados con sesión
        // - Notificar a otros componentes del logout
    }
}
