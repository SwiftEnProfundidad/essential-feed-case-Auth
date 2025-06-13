@preconcurrency import EssentialFeed

public final class InMemoryFailedLoginAttemptsStoreAdapter: FailedLoginAttemptsStoreCleaning {
    private let store = InMemoryFailedLoginAttemptsStore()

    public init() {}

    public func getAttempts(for username: String) -> Int {
        store.getAttempts(for: username)
    }

    public func incrementAttempts(for username: String) async {
        await store.incrementAttempts(for: username)
    }

    public func clearAll() async throws {
        await store.resetAttempts(for: "test@example.com")
    }
}
