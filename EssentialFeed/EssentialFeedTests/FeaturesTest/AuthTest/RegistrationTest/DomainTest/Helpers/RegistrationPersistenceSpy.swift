import EssentialFeed
import Foundation

public final class RegistrationPersistenceSpy: UserRegistrationPersistenceService {
    public func saveCredentials(passwordData: Data, forEmail email: String) -> KeychainSaveResult {
        save(data: passwordData, forKey: email)
    }

    public func saveForOfflineProcessing(registrationData: UserRegistrationData) async throws {
        try await save(registrationData)
    }

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
        case loadTokenBundle
        case deleteTokenBundle
    }

    public var tokenStorageMessages = [TokenStorageMessage]()
    public var tokenStorageSaveTokenCalls = [Token]()
    public var tokenStorageShouldSaveError = false

    public func save(tokenBundle token: Token) async throws {
        if tokenStorageShouldSaveError { throw TestError(id: "tokenStorageSaveTokenError") }
        tokenStorageSaveTokenCalls.append(token)
        tokenStorageMessages.append(.save(tokenBundle: token))
    }

    public var tokenBundleToLoad: Token?
    public var tokenStorageShouldLoadBundleError = false
    public func loadTokenBundle() async throws -> Token? {
        tokenStorageMessages.append(.loadTokenBundle)
        if tokenStorageShouldLoadBundleError { throw TestError(id: "loadTokenBundleError") }
        return tokenBundleToLoad
    }

    public var tokenStorageShouldDeleteBundleError = false
    public func deleteTokenBundle() async throws {
        tokenStorageMessages.append(.deleteTokenBundle)
        if tokenStorageShouldDeleteBundleError { throw TestError(id: "deleteTokenBundleError") }
    }

    public var offlineStoreSaveCalls = [UserRegistrationData]()
    public var offlineStoreShouldSaveThrowError = false
    public func save(_ data: UserRegistrationData) async throws {
        if offlineStoreShouldSaveThrowError { throw TestError(id: "offlineStoreSaveCallsError") }
        offlineStoreSaveCalls.append(data)
    }

    public var keychainDeleteKeyCalls = [String]()
    public var keychainDeleteResults: [Bool] = []

    public func delete(forKey key: String) -> Bool {
        keychainDeleteKeyCalls.append(key)
        guard !keychainDeleteResults.isEmpty else { return true }
        return keychainDeleteResults.removeFirst()
    }

    public var tokenStorageSaveRefreshTokenCalls = [String?]()
    public var tokenToLoad: Token?
    public var tokenStorageDeleteTokenCalled = false
    public var tokenStorageDeleteRefreshTokenCalled = false
}
