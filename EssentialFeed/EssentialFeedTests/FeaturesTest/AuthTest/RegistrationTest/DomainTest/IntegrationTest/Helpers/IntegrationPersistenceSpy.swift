import EssentialFeed
import Foundation

public class IntegrationPersistenceSpy: KeychainProtocol, TokenStorage, OfflineRegistrationStore {
    var saveKeychainDataCalls = [(data: Data, key: String)]()
    var saveKeychainReturnValues: [KeychainSaveResult] = []
    var loadKeychainDataCalls = [String]()
    var dataToReturnForLoad: Data?

    public func save(data: Data, forKey key: String) -> KeychainSaveResult {
        saveKeychainDataCalls.append((data, key))
        return saveKeychainReturnValues.isEmpty ? .success : saveKeychainReturnValues.removeFirst()
    }

    public func load(forKey key: String) -> Data? {
        loadKeychainDataCalls.append(key)
        return dataToReturnForLoad
    }

    enum TokenStorageMessage: Equatable {
        case save(tokenBundle: Token)
        case loadTokenBundle
        case deleteTokenBundle
    }

    var tokenStorageMessages = [TokenStorageMessage]()
    var saveTokenError: Error?
    var tokenBundleToReturn: Token?
    var loadTokenBundleError: Error?
    var deleteTokenBundleError: Error?

    public func save(tokenBundle: Token) async throws {
        tokenStorageMessages.append(.save(tokenBundle: tokenBundle))
        if let error = saveTokenError {
            throw error
        }
    }

    public func loadTokenBundle() async throws -> Token? {
        tokenStorageMessages.append(.loadTokenBundle)
        if let error = loadTokenBundleError {
            throw error
        }
        return tokenBundleToReturn
    }

    public func deleteTokenBundle() async throws {
        tokenStorageMessages.append(.deleteTokenBundle)
        if let error = deleteTokenBundleError {
            throw error
        }
    }

    enum OfflineStoreMessage: Equatable {
        case save(UserRegistrationData)
    }

    var offlineStoreMessages = [OfflineStoreMessage]()
    var saveOfflineDataError: Error?

    public func save(_ data: UserRegistrationData) async throws {
        offlineStoreMessages.append(.save(data))
        if let error = saveOfflineDataError {
            throw error
        }
    }

    func completeSaveTokenBundleSuccessfully() {
        saveTokenError = nil
    }

    func completeSaveTokenBundle(withError error: Error) {
        saveTokenError = error
    }

    func completeLoadTokenBundle(with token: Token?) {
        tokenBundleToReturn = token
        loadTokenBundleError = nil
    }

    func completeLoadTokenBundle(withError error: Error) {
        loadTokenBundleError = error
        tokenBundleToReturn = nil
    }

    func completeDeleteTokenBundleSuccessfully() {
        deleteTokenBundleError = nil
    }

    func completeDeleteTokenBundle(withError error: Error) {
        deleteTokenBundleError = error
    }

    func completeOfflineSaveSuccessfully() {
        saveOfflineDataError = nil
    }

    func completeOfflineSave(withError error: Error) {
        saveOfflineDataError = error
    }
}
