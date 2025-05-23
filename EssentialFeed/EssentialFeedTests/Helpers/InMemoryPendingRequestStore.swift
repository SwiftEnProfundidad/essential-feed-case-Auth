import EssentialFeed

public final class InMemoryPendingRequestStoreSpy<Request: Codable & Equatable>: PendingRequestStore {
    public typealias RequestType = Request

    private var requests: [Request] = []
    public var saveAction: ((Request) -> Void)?

    public init() {}

    public func save(_ request: Request) {
        requests.append(request)
        saveAction?(request)
    }

    public func loadAll() -> [Request] {
        requests
    }

    public func remove(_ request: Request) {
        requests.removeAll { $0 == request }
    }

    public func removeAll() {
        requests.removeAll()
    }
}
