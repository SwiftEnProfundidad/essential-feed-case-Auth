
import Foundation

public protocol OfflineRegistrationLoader {
    func loadAll() async throws -> [UserRegistrationData]
}

public protocol OfflineRegistrationDeleter {
    func delete(_ data: UserRegistrationData) async throws
}

/// Conveniencia para los casos en que se necesitan las 3 operaciones
public typealias OfflineRegistrationStoreCRUD =
        OfflineRegistrationStore & OfflineRegistrationLoader & OfflineRegistrationDeleter
