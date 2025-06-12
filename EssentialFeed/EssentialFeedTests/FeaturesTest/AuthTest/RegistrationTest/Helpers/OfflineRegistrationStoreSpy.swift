import EssentialFeed
import Foundation

public final class OfflineRegistrationStoreSpy: OfflineRegistrationStore, OfflineRegistrationLoader, OfflineRegistrationDeleter, OfflineRegistrationStoreCleaning {
    // MARK: - Message tracking

    public enum Message: Equatable {
        case save(UserRegistrationData)
        case loadAll
        case delete(UserRegistrationData)
        case clearAll
    }

    public private(set) var messages: [Message] = []

    // MARK: - Stubbed results / errors

    public var saveError: Swift.Error?
    private var loadAllResult: Result<[UserRegistrationData], Swift.Error> = .success([])
    public var deleteError: Swift.Error?
    public var clearAllError: Swift.Error?

    public init() {} // Asegurar que sea público

    // MARK: - API

    public func save(_ data: UserRegistrationData) async throws {
        messages.append(.save(data))
        if let error = saveError { throw error }
    }

    public func loadAll() async throws -> [UserRegistrationData] {
        messages.append(.loadAll)
        switch loadAllResult {
        case let .success(registrations):
            return registrations
        case let .failure(error):
            throw error
        }
    }

    public func delete(_ data: UserRegistrationData) async throws {
        messages.append(.delete(data))
        if let error = deleteError { throw error }
    }

    public func clearAll() async throws {
        messages.append(.clearAll)
        if let error = clearAllError { throw error }
        // ADDED: Reset internal state
        loadAllResult = .success([])
    }

    // MARK: - Helpers for tests

    public func completeLoadAll(with registrations: [UserRegistrationData]) {
        loadAllResult = .success(registrations)
    }

    public func completeLoadAll(with error: Swift.Error) {
        loadAllResult = .failure(error)
    }

    public func completeDeletionSuccessfully() {
        deleteError = nil
    }

    public func completeDeletion(with error: Swift.Error) {
        deleteError = error
    }

    public func completeClearAllSuccessfully() {
        clearAllError = nil
    }

    public func completeClearAll(with error: Swift.Error) {
        clearAllError = error
    }
}
