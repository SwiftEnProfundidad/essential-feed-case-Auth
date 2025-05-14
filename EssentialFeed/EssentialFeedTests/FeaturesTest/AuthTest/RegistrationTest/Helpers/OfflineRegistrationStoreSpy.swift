// ADD: conformar a los nuevos protocolos
final class OfflineRegistrationStoreSpy: OfflineRegistrationStore, OfflineRegistrationLoader, OfflineRegistrationDeleter {
    // EXISTENTE ----------------------------------------------------------------
    enum Message: Equatable {
        case save(UserRegistrationData)
        case loadAll // ADD
        case delete(UserRegistrationData) // ADD
    }

    private(set) var messages = [Message]()
    private var stored = [UserRegistrationData]()

    // MARK: - OfflineRegistrationStore

    func save(_ data: UserRegistrationData) async throws {
        messages.append(.save(data))
        stored.append(data)
    }

    // MARK: - OfflineRegistrationLoader

    func loadAll() async throws -> [UserRegistrationData] {
        messages.append(.loadAll)
        return stored
    }

    // MARK: - OfflineRegistrationDeleter

    func delete(_ data: UserRegistrationData) async throws {
        messages.append(.delete(data))
        stored.removeAll { $0 == data }
    }

    // Helpers para tests -------------------------------------------------------
    func completeLoadAll(with data: [UserRegistrationData]) {
        stored = data
    }

    func completeDeletionSuccessfully() { /* no-op, ya borra por defecto */ }
}
