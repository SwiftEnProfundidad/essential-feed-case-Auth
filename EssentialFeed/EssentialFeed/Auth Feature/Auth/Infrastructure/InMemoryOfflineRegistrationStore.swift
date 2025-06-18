import Foundation

public final class InMemoryOfflineRegistrationStore: OfflineRegistrationStore {
    private var storedData: [UserRegistrationData] = []

    public init() {}

    public func save(_ data: UserRegistrationData) async throws {
        storedData.append(data)
    }
}
