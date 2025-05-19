import Foundation

public protocol OfflineLoginStoring {
    func save(credentials: LoginCredentials) async throws
}

public protocol OfflineLoginLoading {
    func loadAll() async -> [LoginCredentials]
}

public protocol OfflineLoginDeleting {
    func delete(credentials: LoginCredentials) async throws
}

public typealias OfflineLoginStore = OfflineLoginDeleting & OfflineLoginLoading & OfflineLoginStoring
