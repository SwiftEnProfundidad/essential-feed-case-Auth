@preconcurrency import EssentialFeed

public final class InMemoryOfflineRegistrationStoreSpy: OfflineRegistrationStoreCleaning {
    public var receivedUserRegistrationData: [UserRegistrationData] = []

    public init() {}

    public func clearAll() async throws {
        receivedUserRegistrationData.removeAll()
    }
}
