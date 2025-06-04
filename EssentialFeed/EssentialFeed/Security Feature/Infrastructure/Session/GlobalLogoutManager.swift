import Foundation

public final class GlobalLogoutManager: SessionLogoutManager {
    private let tokenStorage: TokenStorage

    public init(tokenStorage: TokenStorage) {
        self.tokenStorage = tokenStorage
    }

    public func performGlobalLogout() async throws {
        try await tokenStorage.deleteTokenBundle()

        // Aquí podríamos añadir más limpieza si fuera necesario:
        // - Limpiar cache de usuario
        // - Limpiar UserDefaults relacionados con sesión
        // - Notificar a otros componentes del logout
    }
}
