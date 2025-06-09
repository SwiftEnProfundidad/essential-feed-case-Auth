import EssentialFeed
import Foundation

class OfflineLoginStoreSpy: OfflineLoginStore {
    private(set) var saveCalls: [LoginCredentials] = []
    private(set) var loadAllCalls: Int = 0
    private(set) var deleteCalls: [LoginCredentials] = []

    var saveError: Error?
    var loadAllError: Error?
    var deleteError: Error?
    var stubbedCredentials: [LoginCredentials] = []

    func save(credentials: LoginCredentials) async throws {
        saveCalls.append(credentials)
        if let error = saveError {
            throw error
        }
    }

    func loadAll() async throws -> [LoginCredentials] {
        loadAllCalls += 1
        if let error = loadAllError {
            throw error
        }
        return stubbedCredentials
    }

    func delete(credentials: LoginCredentials) async throws {
        deleteCalls.append(credentials)
        if let error = deleteError {
            throw error
        }
    }
}
