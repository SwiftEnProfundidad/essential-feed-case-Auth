import EssentialFeed
import Foundation

public final class OfflineLoginStoreSpy: OfflineLoginStore, OfflineLoginStoreCleaning {
    public enum Message: Equatable {
        case save(credentials: LoginCredentials)
        case loadAll
        case delete(credentials: LoginCredentials)
        case clearAll
    }

    public private(set) var messages = [Message]()

    public var loadAllStub: [LoginCredentials] = []
    public var saveError: Error?
    public var deleteError: Error?
    public var clearAllError: Error?

    public init() {}

    // MARK: - OfflineLoginLoading

    public func loadAll() async -> [LoginCredentials] {
        messages.append(.loadAll)
        return loadAllStub
    }

    // MARK: - OfflineLoginStore

    public func save(credentials: LoginCredentials) async throws {
        messages.append(.save(credentials: credentials))
        if let saveError {
            throw saveError
        }
    }

    public func delete(credentials: LoginCredentials) async throws {
        messages.append(.delete(credentials: credentials))
        if let deleteError {
            throw deleteError
        }
    }

    // MARK: - OfflineLoginStoreCleaning

    public func clearAll() async throws {
        messages.append(.clearAll)
        if let clearAllError {
            throw clearAllError
        }
        loadAllStub = []
    }

    // MARK: - Stubbing helpers (Estos deben ser thread-safe si se llaman concurrentemente)

    public func stubLoadAll(with credentials: [LoginCredentials]) {
        loadAllStub = credentials
    }

    public func completeSave(with error: Error) {
        saveError = error
    }

    public func completeSaveSuccessfully() {
        saveError = nil
    }

    public func completeDelete(with error: Error) {
        deleteError = error
    }

    public func completeDeleteSuccessfully() {
        deleteError = nil
    }

    public func completeClearAll(with error: Error) {
        clearAllError = error
    }

    public func completeClearAllSuccessfully() {
        clearAllError = nil
    }
}
