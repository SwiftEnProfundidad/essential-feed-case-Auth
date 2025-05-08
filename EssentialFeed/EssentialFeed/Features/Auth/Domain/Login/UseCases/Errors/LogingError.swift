
import Foundation

/// Errores posibles durante el proceso de login.
public enum LoginError: Error, Equatable {
	case invalidCredentials
	case invalidEmailFormat
	case invalidPasswordFormat
	case network            // Error genérico de red/API
	case tokenStorageFailed // Fallo al guardar el token
	case noConnectivity     // Sin conexión
	case unknown
	case offlineStoreFailed // Fallo al guardar en store offline
}
