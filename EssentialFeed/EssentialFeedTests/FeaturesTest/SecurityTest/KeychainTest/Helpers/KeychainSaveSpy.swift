// This helper is intended for advanced Keychain tests with a fully simulated API.
// If you only need to spy on simple saves/deletes in unit tests, use the general-purpose KeychainSpy in EssentialFeedTests/Helpers/KeychainSpy.swift

import EssentialFeed
import Foundation

// MARK: - KeychainSaveSpy (advanced test double)

public final class KeychainSaveSpy: KeychainSavable {
    public var receivedKey: String?
    public var receivedData: Data?
    public var saveResult: KeychainSaveResult = .success
    public var saveCalled = false
    public var saveCallCount = 0
    public var lastData: Data?
    public var lastKey: String?
    public var simulatedError: Int?

    public init() {}

    public func save(data: Data, forKey key: String) -> KeychainSaveResult {
        if let error = simulatedError {
            if error == -25299 {
                return .duplicateItem
            }
            return .failure
        }
        saveCalled = true
        saveCallCount += 1
        lastData = data
        lastKey = key
        receivedKey = key
        receivedData = data
        return saveResult
    }

    public func load(forKey key: String) -> Data? {
        receivedKey == key ? receivedData : nil
    }
}
