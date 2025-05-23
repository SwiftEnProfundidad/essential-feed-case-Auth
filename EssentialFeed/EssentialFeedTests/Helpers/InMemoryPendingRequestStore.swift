import EssentialFeed

class InMemoryPendingRequestStore<Request: Equatable>: PendingRequestStore {
    private(set) var savedRequests = [Request]()
    var save: ((Request) -> Void)?

    func save(_ request: Request) {
        savedRequests.append(request)
        save?(request)
    }

    func loadAll() -> [Request] {
        savedRequests
    }

    func remove(_ request: Request) {
        savedRequests.removeAll { $0 == request }
    }

    func removeAll() {
        savedRequests.removeAll()
    }
}

// MARK: - PendingRequestStore Protocol

protocol PendingRequestStore {
    associatedtype Request: Equatable
    func save(_ request: Request)
    func loadAll() -> [Request]
    func remove(_ request: Request)
    func removeAll()
}
