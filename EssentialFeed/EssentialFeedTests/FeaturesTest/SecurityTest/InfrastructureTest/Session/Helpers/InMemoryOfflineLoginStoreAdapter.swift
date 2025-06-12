@preconcurrency import EssentialFeed

public final class InMemoryOfflineLoginStoreAdapter: OfflineLoginStoreCleaning {
    public var savedCredentials: [LoginCredentials] = []

    public init() {}

    public func saveCredentials(_ credentials: LoginCredentials) async {
        savedCredentials.append(credentials)
    }

    public func clearAll() async throws {
        savedCredentials.removeAll()
    }
}
