import EssentialFeed
import Foundation

final class OfflineRegistrationStoreSpy: OfflineRegistrationStore, OfflineRegistrationLoader, OfflineRegistrationDeleter, OfflineRegistrationStoreCleaning {
    // MARK: - Message tracking

    enum Message: Equatable {
        case save(UserRegistrationData)
        case loadAll
        case delete(UserRegistrationData)
        case clearAll
    }

    private(set) var messages: [Message] = []

    // MARK: - Stubbed results / errors

    var saveError: Swift.Error?
    private var loadAllResult: Result<[UserRegistrationData], Swift.Error> = .success([])
    var deleteError: Swift.Error?
    var clearAllError: Swift.Error?

    // MARK: - API

    func save(_ data: UserRegistrationData) async throws {
        messages.append(.save(data))
        if let error = saveError { throw error }
    }

    func loadAll() async throws -> [UserRegistrationData] {
        messages.append(.loadAll)
        switch loadAllResult {
        case let .success(registrations):
            return registrations
        case let .failure(error):
            throw error
        }
    }

    func delete(_ data: UserRegistrationData) async throws {
        messages.append(.delete(data))
        if let error = deleteError { throw error }
    }

    func clearAll() async throws {
        messages.append(.clearAll)
        if let error = clearAllError { throw error }
    }

    // MARK: - Helpers for tests

    func completeLoadAll(with registrations: [UserRegistrationData]) {
        loadAllResult = .success(registrations)
    }

    func completeLoadAll(with error: Swift.Error) {
        loadAllResult = .failure(error)
    }

    func completeDeletionSuccessfully() {
        deleteError = nil
    }

    func completeDeletion(with error: Swift.Error) {
        deleteError = error
    }

    func completeClearAllSuccessfully() {
        clearAllError = nil
    }

    func completeClearAll(with error: Swift.Error) {
        clearAllError = error
    }
}
