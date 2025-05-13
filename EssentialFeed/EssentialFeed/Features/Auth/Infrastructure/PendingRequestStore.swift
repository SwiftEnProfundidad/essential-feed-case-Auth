import Foundation

public protocol PendingRequestSaver {
    associatedtype RequestType: Codable & Equatable
    func save(_ request: RequestType)
}

public protocol PendingRequestLoader {
    associatedtype RequestType: Codable & Equatable
    func loadAll() -> [RequestType]
}

public protocol PendingRequestRemover {
    associatedtype RequestType: Codable & Equatable
    func remove(_ request: RequestType)
    func removeAll()
}

public typealias PendingRequestStore = PendingRequestLoader & PendingRequestRemover & PendingRequestSaver

public final class InMemoryPendingRequestStore<Request: Codable & Equatable>: PendingRequestStore {
    private var requests: [Request] = []
    public init() {}
    public func save(_ request: Request) { requests.append(request) }
    public func loadAll() -> [Request] { requests }
    public func remove(_ request: Request) { requests.removeAll { $0 == request } }
    public func removeAll() { requests.removeAll() }
}
