import EssentialFeed
import Foundation

typealias ComprehensiveRegistrationPersistence = KeychainProtocol & OfflineRegistrationStore & TokenStorage

public class IntegrationPersistenceSpy: ComprehensiveRegistrationPersistence {
    public var keychainSaveDataCalls = [(data: Data, key: String)]()
    public var keychainSaveResults: [KeychainSaveResult] = []
    public var keychainLoadKeyCalls = [String]()
    public var keychainLoadDataToReturn: Data?

    public enum TokenStorageMessage: Equatable {
        case save(tokenBundle: Token)
        case loadTokenBundle
        case deleteTokenBundle
    }

    public var tokenStorageMessages = [TokenStorageMessage]()
    public var tokenStorageSaveTokenCalls = [Token]()
    public var tokenStorageShouldSaveError = false
    public var tokenBundleToLoad: Token?
    public var tokenStorageShouldLoadBundleError = false
    public var tokenStorageShouldDeleteBundleError = false
    public var offlineStoreSaveCalls = [UserRegistrationData]()
    public var offlineStoreShouldSaveThrowError = false

    public func save(data: Data, forKey key: String) -> KeychainSaveResult {
        keychainSaveDataCalls.append((data, key))
        guard !keychainSaveResults.isEmpty else { return .success }
        return keychainSaveResults.removeFirst()
    }

    public func load(forKey key: String) -> Data? {
        keychainLoadKeyCalls.append(key)
        return keychainLoadDataToReturn
    }

    public func save(tokenBundle token: Token) async throws {
        if tokenStorageShouldSaveError { throw TestError(id: "tokenStorageSaveTokenError") }
        tokenStorageSaveTokenCalls.append(token)
        tokenStorageMessages.append(.save(tokenBundle: token))
    }

    public func loadTokenBundle() async throws -> Token? {
        tokenStorageMessages.append(.loadTokenBundle)
        if tokenStorageShouldLoadBundleError { throw TestError(id: "loadTokenBundleError") }
        return tokenBundleToLoad
    }

    public func deleteTokenBundle() async throws {
        tokenStorageMessages.append(.deleteTokenBundle)
        if tokenStorageShouldDeleteBundleError { throw TestError(id: "deleteTokenBundleError") }
    }

    public func save(_ data: UserRegistrationData) async throws {
        if offlineStoreShouldSaveThrowError { throw TestError(id: "offlineStoreSaveCallsError") }
        offlineStoreSaveCalls.append(data)
    }
}
