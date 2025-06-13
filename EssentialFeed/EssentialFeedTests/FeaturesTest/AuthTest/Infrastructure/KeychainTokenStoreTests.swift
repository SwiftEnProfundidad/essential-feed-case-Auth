import CryptoKit
import EssentialFeed
import XCTest

final class KeychainTokenStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        deleteTestTokenFromKeychain(key: testTokenKeychainKey())
    }

    override func tearDown() {
        deleteTestTokenFromKeychain(key: testTokenKeychainKey())
        super.tearDown()
    }

    func test_save_storesTokenEncryptedInKeychain() async throws {
        let (sut, keychainManagerSpy) = makeSUT()
        let token = makeTestToken()
        deleteTestTokenFromKeychain(key: testTokenKeychainKey())

        try await sut.save(tokenBundle: token)

        let savedMessages = keychainManagerSpy.messages.filter {
            if case .save(_, key: testTokenKeychainKey()) = $0 { return true }
            return false
        }
        XCTAssertEqual(savedMessages.count, 1, "Save should be called once on the keychain manager")

        if case let .save(data, _) = savedMessages.first {
            let tokenJSON = try JSONEncoder().encode(token)
            XCTAssertNotEqual(data, tokenJSON, "Stored data by spy should represent what KeychainManager would have stored (i.e., encrypted), not plain JSON")
        } else {
            XCTFail("No save message found in spy for the correct key.")
        }
    }

    func test_loadTokenBundle_retrievesSavedTokenFromKeychain() async throws {
        let (sut, keychainManagerSpy) = makeSUT()
        let tokenToSave = makeTestToken()
        deleteTestTokenFromKeychain(key: testTokenKeychainKey())

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let tokenData = try encoder.encode(tokenToSave)

        try keychainManagerSpy.simulateSave(data: tokenData, forKey: testTokenKeychainKey())

        let loadedToken = try await sut.loadTokenBundle()

        XCTAssertNotNil(loadedToken, "Should load a token from Keychain")
        guard let actualLoadedToken = loadedToken else {
            XCTFail("Failed to unwrap loaded token")
            return
        }
        XCTAssertEqual(actualLoadedToken.accessToken, tokenToSave.accessToken, "Loaded access token should match saved token")
        XCTAssertEqual(actualLoadedToken.refreshToken, tokenToSave.refreshToken, "Loaded refresh token should match saved token")
        XCTAssertEqual(actualLoadedToken.expiry.timeIntervalSince1970, tokenToSave.expiry.timeIntervalSince1970, accuracy: 1, "Loaded expiry should match saved token within 1 second accuracy")
    }

    func test_loadTokenBundle_whenNoTokenSaved_returnsNil() async throws {
        let (sut, keychainManagerSpy) = makeSUT()
        deleteTestTokenFromKeychain(key: testTokenKeychainKey())
        keychainManagerSpy.simulateNoDataFound(forKey: testTokenKeychainKey())

        let loadedToken = try await sut.loadTokenBundle()

        XCTAssertNil(loadedToken, "Should return nil when no token is saved in Keychain")
    }

    func test_loadTokenBundle_whenKeychainDataIsCorrupt_throwsDecodingError() async throws {
        let (sut, keychainManagerSpy) = makeSUT()
        let corruptData = Data("corrupt_data".utf8)
        deleteTestTokenFromKeychain(key: testTokenKeychainKey())

        try keychainManagerSpy.simulateSave(data: corruptData, forKey: testTokenKeychainKey())

        do {
            _ = try await sut.loadTokenBundle()
            XCTFail("Expected loadTokenBundle to throw a decoding error for corrupt data")
        } catch TokenStorageError.decodingFailed {
        } catch {
            XCTFail("Expected TokenStorageError.decodingFailed, got \(error) instead")
        }
    }

    func test_deleteTokenBundle_removesTokenFromKeychain() async throws {
        let (sut, keychainManagerSpy) = makeSUT()
        let tokenToSaveAndDelete = makeTestToken()
        deleteTestTokenFromKeychain(key: testTokenKeychainKey())

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let tokenData = try encoder.encode(tokenToSaveAndDelete)
        try keychainManagerSpy.simulateSave(data: tokenData, forKey: testTokenKeychainKey())

        var loadedDataFromSpy = try keychainManagerSpy.load(forKey: testTokenKeychainKey())
        XCTAssertNotNil(loadedDataFromSpy, "Token should be in spy's Keychain before deletion")

        try await sut.deleteTokenBundle()

        let deleteMessages = keychainManagerSpy.messages.filter {
            if case .delete(testTokenKeychainKey()) = $0 { return true }
            return false
        }
        XCTAssertEqual(deleteMessages.count, 1, "Delete should be called once on keychain manager for the correct key")

        loadedDataFromSpy = try? keychainManagerSpy.load(forKey: testTokenKeychainKey())
        XCTAssertNil(loadedDataFromSpy, "Token should be removed from spy's Keychain after deletion")
    }

    func test_deleteTokenBundle_whenNoTokenSaved_completesWithoutError() async throws {
        let (sut, keychainManagerSpy) = makeSUT()
        deleteTestTokenFromKeychain(key: testTokenKeychainKey())
        keychainManagerSpy.simulateNoDataFound(forKey: testTokenKeychainKey())

        try await sut.deleteTokenBundle()

        let deleteMessages = keychainManagerSpy.messages.filter {
            if case .delete(testTokenKeychainKey()) = $0 { return true }
            return false
        }
        XCTAssertEqual(deleteMessages.count, 1, "Delete should be called on keychain manager even if no token was present")
    }

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: KeychainTokenStore, keychainManagerSpy: KeychainManagerSpyForTokenStore) {
        let keychainManagerSpy = KeychainManagerSpyForTokenStore()
        let sut = KeychainTokenStore(keychainManager: keychainManagerSpy, tokenKeychainKey: testTokenKeychainKey())

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(keychainManagerSpy, file: file, line: line)

        return (sut, keychainManagerSpy)
    }

    private func makeTestToken() -> Token {
        Token(
            accessToken: "test-access-\(UUID().uuidString)",
            expiry: Date().addingTimeInterval(3600),
            refreshToken: "test-refresh-\(UUID().uuidString)"
        )
    }

    private func testTokenKeychainKey() -> String {
        "test.com.essentialfeed.authTokenBundle.for.keychaintokentests"
    }

    private func deleteTestTokenFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private class KeychainManagerSpyForTokenStore: KeychainReader, KeychainWriter, @unchecked Sendable {
    enum Message: Equatable {
        case save(data: Data, key: String)
        case load(key: String)
        case delete(key: String)
    }

    private(set) var messages = [Message]()
    private var storedValues = [String: Data]()
    private var loadError: Error?
    private var saveError: Error?
    private var deleteError: Error?

    init() {}

    func save(data: Data, forKey key: String) throws {
        if let saveError {
            throw saveError
        }
        messages.append(.save(data: data, key: key))
        storedValues[key] = data
    }

    func delete(forKey key: String) throws {
        if let deleteError {
            throw deleteError
        }
        messages.append(.delete(key: key))
        storedValues[key] = nil
    }

    func load(forKey key: String) throws -> Data? {
        if let loadError {
            throw loadError
        }
        messages.append(.load(key: key))
        return storedValues[key]
    }

    func simulateSave(data: Data, forKey key: String) throws {
        storedValues[key] = data
    }

    func simulateNoDataFound(forKey key: String) {
        storedValues[key] = nil
    }

    func stubLoadError(_ error: Error) {
        loadError = error
    }

    func stubSaveError(_ error: Error) {
        saveError = error
    }

    func stubDeleteError(_ error: Error) {
        deleteError = error
    }
}
