@preconcurrency import EssentialFeed
import XCTest

final class KeychainTokenStoreIntegrationTests: XCTestCase {
    func test_save_load_and_delete_tokenBundle_flow() async throws {
        let (sut, key, systemKeychain) = makeSUT()
        let token = Token(accessToken: "access-\(UUID().uuidString)", expiry: Date().addingTimeInterval(123), refreshToken: "refresh-\(UUID().uuidString)")

        try await sut.save(tokenBundle: token)
        let loadedToken = try await sut.loadTokenBundle()
        XCTAssertEqual(loadedToken, token, "Should load the same token that was saved")

        try await sut.deleteTokenBundle()
        let shouldBeNil = try await sut.loadTokenBundle()
        XCTAssertNil(shouldBeNil, "Token bundle should be nil after deletion")

        _ = systemKeychain.delete(forKey: key)
    }

    func test_deleteTokenBundle_nonexistent_is_idempotent() async throws {
        let (sut, _, _) = makeSUT()
        do {
            try await sut.deleteTokenBundle()
        } catch {
            XCTFail("Deleting non-existent tokenBundle should not fail: \(error)")
        }
    }

    func test_overwrite_tokenBundle_replaces_existing_value() async throws {
        let (sut, key, systemKeychain) = makeSUT()
        let token1 = Token(accessToken: "old-\(UUID().uuidString)", expiry: Date().addingTimeInterval(70), refreshToken: "refresh1")
        let token2 = Token(accessToken: "new-\(UUID().uuidString)", expiry: Date().addingTimeInterval(10000), refreshToken: "refresh2")

        try await sut.save(tokenBundle: token1)
        try await sut.save(tokenBundle: token2)
        let loaded = try await sut.loadTokenBundle()
        XCTAssertEqual(loaded, token2, "Should load the latest token after overwrite")

        _ = systemKeychain.delete(forKey: key)
    }

    func test_save_invalidTokenData_doesNotCrashAndThrows() async throws {
        let (sut, key, systemKeychain) = makeSUT()
        let invalidData = Data([0xFF, 0xFE, 0xFD])
        _ = systemKeychain.save(data: invalidData, forKey: key)
        do {
            _ = try await sut.loadTokenBundle()
            XCTFail("Should throw decodingFailed error if token data is corrupted")
        } catch let error as TokenStorageError {
            switch error {
            case .decodingFailed: break
            default: XCTFail("Should throw decodingFailed, got \(error)")
            }
        } catch {
            XCTFail("Should only throw TokenStorageError.decodingFailed, got \(error)")
        }
        _ = systemKeychain.delete(forKey: key)
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: KeychainTokenStore, key: String, systemKeychain: SystemKeychain) {
        let systemKeychain = SystemKeychain()
        let adapter = SystemKeychainAdapter(systemKeychain: systemKeychain)
        let key = "e2e-token-\(UUID().uuidString)"
        let keychainManager = KeychainManager(
            reader: adapter,
            writer: adapter,
            encryptor: PassthroughEncryptor(),
            errorHandler: SilentKeychainErrorHandlerAdapter()
        )
        let sut = KeychainTokenStore(keychainManager: keychainManager, tokenKeychainKey: key)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(keychainManager, file: file, line: line)
        return (sut, key, systemKeychain)
    }
}
