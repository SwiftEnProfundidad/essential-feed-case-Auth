import EssentialFeed
import Foundation

public final class RegistrationPersistenceSpy: TokenWriter, KeychainSavable, OfflineRegistrationStore {
    public var keychainSaveDataCalls = [(data: Data, key: String)]()
    public var keychainSaveResults: [KeychainSaveResult] = []

    public func save(data: Data, forKey key: String) -> KeychainSaveResult {
        keychainSaveDataCalls.append((data, key))
        guard !keychainSaveResults.isEmpty else { return .success }
        return keychainSaveResults.removeFirst()
    }

    public var keychainLoadKeyCalls = [String]()
    public var keychainLoadDataToReturn: Data?

    public func load(forKey key: String) -> Data? {
        keychainLoadKeyCalls.append(key)
        return keychainLoadDataToReturn
    }

    public enum TokenStorageMessage: Equatable {
        case save(tokenBundle: Token)
    }

    public var tokenStorageMessages = [TokenStorageMessage]()
    public var tokenStorageSaveTokenCalls = [Token]()
    public var tokenStorageShouldSaveError = false

    public func save(tokenBundle token: Token) async throws {
        if tokenStorageShouldSaveError { throw TestError(id: "tokenStorageSaveTokenError") }
        tokenStorageSaveTokenCalls.append(token)
        tokenStorageMessages.append(.save(tokenBundle: token))
    }

    public var offlineStoreSaveCalls = [UserRegistrationData]()
    public var offlineStoreShouldSaveThrowError = false

    public func save(_ data: UserRegistrationData) async throws {
        if offlineStoreShouldSaveThrowError { throw TestError(id: "offlineStoreSaveCallsError") }
        offlineStoreSaveCalls.append(data)
    }
}
