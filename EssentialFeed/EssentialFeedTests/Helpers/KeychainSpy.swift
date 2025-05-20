import Foundation

public final class KeychainSpy {
    public private(set) var savedItems: [String] = []

    public private(set) var saveCallCount = 0
    public private(set) var receivedValueToSave: String?

    public init() {}

    public func save(_ encryptedToken: String) {
        savedItems.append(encryptedToken)

        saveCallCount += 1
        receivedValueToSave = encryptedToken
    }
}
