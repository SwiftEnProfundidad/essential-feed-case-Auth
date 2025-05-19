public protocol OfflineLoginStore {
    func loadAll() async -> [LoginCredentials]
    func save(credentials: LoginCredentials) async throws
    func delete(credentials: LoginCredentials) async throws
}
