@preconcurrency import EssentialFeed
import Foundation

// MARK: - Simple In-Memory Store for Demo

final class InMemoryOfflineLoginStore: OfflineLoginStore, OfflineLoginStoreCleaning, @unchecked Sendable {
    private var credentials: [LoginCredentials] = []

    func save(credentials: LoginCredentials) async throws {
        self.credentials.append(credentials)
    }

    func loadAll() async throws -> [LoginCredentials] {
        credentials
    }

    func delete(credentials: LoginCredentials) async throws {
        self.credentials.removeAll { $0.email == credentials.email }
    }

    func clearAll() async throws {
        self.credentials.removeAll()
    }
}
