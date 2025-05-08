
import Foundation

public protocol OfflineRegistrationStore {
	func save(_ data: UserRegistrationData) async throws
}

public protocol OfflineRegistrationLoader {
	func loadAll() async throws -> [UserRegistrationData]
}

public protocol OfflineRegistrationDeleter {
	func delete(_ data: UserRegistrationData) async throws
}

public typealias OfflineRegistrationStoreCRUD = OfflineRegistrationStore & OfflineRegistrationLoader & OfflineRegistrationDeleter
