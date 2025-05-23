import Foundation

public final class AnyLoginRequestStore: PendingRequestStore {
    public typealias RequestType = LoginRequest

    private let _save: (LoginRequest) -> Void
    private let _loadAll: () -> [LoginRequest]
    private let _remove: (LoginRequest) -> Void
    private let _removeAll: () -> Void

    public init<Store: PendingRequestStore>(_ store: Store) where Store.RequestType == LoginRequest {
        _save = store.save
        _loadAll = store.loadAll
        _remove = store.remove
        _removeAll = store.removeAll
    }

    public func save(_ request: LoginRequest) { _save(request) }
    public func loadAll() -> [LoginRequest] { _loadAll() }
    public func remove(_ request: LoginRequest) { _remove(request) }
    public func removeAll() { _removeAll() }
}
