import Foundation

public final class AnyLoginRequestStore {
	private let _save: (LoginRequest) -> Void
	private let _loadAll: () -> [LoginRequest]
	private let _remove: (LoginRequest) -> Void
	private let _removeAll: () -> Void
	
	public init<Store: PendingRequestSaver & PendingRequestLoader & PendingRequestRemover>(_ store: Store) where Store.RequestType == LoginRequest {
		_save = store.save
		_loadAll = store.loadAll
		_remove = store.remove
		_removeAll = store.removeAll
	}
	
	func save(_ request: LoginRequest) { _save(request) }
	func loadAll() -> [LoginRequest] { _loadAll() }
	func remove(_ request: LoginRequest) { _remove(request) }
	func removeAll() { _removeAll() }
}
