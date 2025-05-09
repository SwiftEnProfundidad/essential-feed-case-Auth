import EssentialFeed
import Foundation

// Conforma al CRUD completo: save + loadAll + delete
final class OfflineRegistrationStoreSpy: OfflineRegistrationStore, OfflineRegistrationLoader, OfflineRegistrationDeleter {

    // MARK: - Message tracking
    enum Message: Equatable {
        case save(UserRegistrationData)
        case loadAll
        case delete(UserRegistrationData)
    }

    // FIX: inicializador del array para evitar error de sintaxis
    private(set) var messages: [Message] = []

    // MARK: - Stubbed results / errors
    var saveError: Swift.Error?
    private var loadAllResult: Result<[UserRegistrationData], Swift.Error> = .success([])
    var deleteError: Swift.Error?

    // MARK: - API

    func save(_ data: UserRegistrationData) async throws {
        messages.append(.save(data))
        if let error = saveError { throw error }
    }

    func loadAll() async throws -> [UserRegistrationData] {
        messages.append(.loadAll)
        switch loadAllResult {
        case .success(let registrations):
            return registrations
        case .failure(let error):
            throw error
        }
    }

    func delete(_ data: UserRegistrationData) async throws {
        messages.append(.delete(data))
        if let error = deleteError { throw error }
    }

    // MARK: - Helpers for tests

    /// Inyecta un resultado exitoso para `loadAll()`
    func completeLoadAll(with registrations: [UserRegistrationData]) {
        loadAllResult = .success(registrations)
    }

    /// Inyecta un resultado fallido para `loadAll()`
    func completeLoadAll(with error: Swift.Error) {
        loadAllResult = .failure(error)
    }

    /// Configura la eliminación para que NO falle (por defecto ya es así)
    func completeDeletionSuccessfully() {
        deleteError = nil
    }

    /// Configura la eliminación para lanzar un error
    func completeDeletion(with error: Swift.Error) {
        deleteError = error
    }
}
