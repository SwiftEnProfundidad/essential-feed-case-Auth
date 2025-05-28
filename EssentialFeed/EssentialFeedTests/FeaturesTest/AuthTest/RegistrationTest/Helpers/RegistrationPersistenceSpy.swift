import EssentialFeed
import Foundation

final class RegistrationPersistenceSpy: UserRegistrationPersistenceService {
    func saveCredentials(passwordData: Data, forEmail email: String) -> KeychainSaveResult {
        save(data: passwordData, forKey: email)
    }

    func saveForOfflineProcessing(registrationData: UserRegistrationData) async throws {
        try await save(registrationData)
    }

    var keychainSaveDataCalls = [(data: Data, key: String)]()
    var keychainSaveResults: [KeychainSaveResult] = []
    private var savedData = [String: Data]()
    func save(data: Data, forKey key: String) -> KeychainSaveResult {
        keychainSaveDataCalls.append((data, key))
        savedData[key] = data
        guard !keychainSaveResults.isEmpty else { return .success }
        return keychainSaveResults.removeFirst()
    }

    var keychainLoadKeyCalls = [String]()
    var keychainLoadDataToReturn: Data?
    func load(forKey key: String) -> Data? {
        keychainLoadKeyCalls.append(key)
        return keychainLoadDataToReturn ?? savedData[key]
    }

    enum TokenStorageMessage: Equatable {
        case save(tokenBundle: Token)
        case loadTokenBundle
        case deleteTokenBundle
    }

    var tokenStorageMessages = [TokenStorageMessage]()
    var tokenStorageSaveTokenCalls = [Token]()
    var tokenStorageShouldSaveError = false

    func save(tokenBundle token: Token) async throws {
        if tokenStorageShouldSaveError { throw TestError(id: "tokenStorageSaveTokenError") }
        tokenStorageSaveTokenCalls.append(token)
        tokenStorageMessages.append(.save(tokenBundle: token))
    }

    var tokenBundleToLoad: Token?
    var tokenStorageShouldLoadBundleError = false
    func loadTokenBundle() async throws -> Token? {
        tokenStorageMessages.append(.loadTokenBundle)
        if tokenStorageShouldLoadBundleError { throw TestError(id: "loadTokenBundleError") }
        return tokenBundleToLoad
    }

    var tokenStorageShouldDeleteBundleError = false
    func deleteTokenBundle() async throws {
        tokenStorageMessages.append(.deleteTokenBundle)
        if tokenStorageShouldDeleteBundleError { throw TestError(id: "deleteTokenBundleError") }
    }

    var offlineStoreSaveCalls = [UserRegistrationData]()
    var offlineStoreShouldSaveThrowError = false
    func save(_ data: UserRegistrationData) async throws {
        if offlineStoreShouldSaveThrowError { throw TestError(id: "offlineStoreSaveCallsError") }
        offlineStoreSaveCalls.append(data)
    }

    var keychainDeleteKeyCalls = [String]()
    var keychainDeleteResults: [Bool] = []

    func delete(forKey key: String) -> Bool {
        keychainDeleteKeyCalls.append(key)
        guard !keychainDeleteResults.isEmpty else { return true }
        return keychainDeleteResults.removeFirst()
    }

    var tokenStorageSaveRefreshTokenCalls = [String?]()
    var tokenToLoad: Token?
    var tokenStorageDeleteTokenCalled = false
    var tokenStorageDeleteRefreshTokenCalled = false
}
