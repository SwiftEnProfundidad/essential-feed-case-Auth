
import Foundation

/// Guarda la solicitud de registro para reintento offline.
/// Mantiene ISP: solo la operación **save**.
public protocol OfflineRegistrationStore {
	func save(_ data: UserRegistrationData) async throws
}
