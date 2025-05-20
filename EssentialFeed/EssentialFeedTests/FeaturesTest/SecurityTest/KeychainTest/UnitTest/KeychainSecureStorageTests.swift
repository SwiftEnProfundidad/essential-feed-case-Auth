import EssentialFeed
import XCTest

// CU: Seguridad de almacenamiento en Keychain
// Checklist: Validar operaciones seguras en Keychain
final class KeychainSecureStorageTests: XCTestCase {
    func test_saveData_succeeds_whenKeychainSavesSuccessfully() {
        let (sut, keychain, _, _) = makeDefaultSUT()
        let key = "test-key"
        let data = "test-data".data(using: .utf8)!
        keychain.saveResultToReturn = .success

        let result = sut.save(data: data, forKey: key)

        XCTAssertEqual(keychain.receivedSaveKey, key)
        XCTAssertEqual(keychain.receivedSaveData, data)
        XCTAssertEqual(sut.load(forKey: key), data, "Loaded data should match saved data")
        XCTAssertEqual(result, KeychainSaveResult.success, "Save should succeed with valid input")
    }

    func test_saveData_fails_whenKeychainReturnsError() {
        let (sut, keychain, fallback, alternative) = makeDefaultSUT()
        let key = "test-key"
        let data = "test-data".data(using: .utf8)!
        keychain.saveResultToReturn = .failure
        fallback.saveResultToReturn = .failure
        alternative.saveResultToReturn = .failure
        keychain.willValidateAfterSave = { [weak keychain] (corruptedKey: String) in
            keychain?.simulateCorruption(forKey: corruptedKey)
        }

        let result = sut.save(data: data, forKey: key)

        XCTAssertEqual(keychain.receivedSaveKey, key)
        XCTAssertEqual(keychain.receivedSaveData, data)
        assertEventuallyEqual(sut.load(forKey: key), nil)
        XCTAssertEqual(result, KeychainSaveResult.failure, "Save should fail with invalid input")
    }

    func test_saveData_usesFallback_whenKeychainFails() {
        let (sut, keychain, fallback, _) = makeDefaultSUT()
        let key = "test-key"
        let data = "test-data".data(using: .utf8)!
        keychain.saveResultToReturn = .failure
        fallback.saveResultToReturn = .success
        keychain.willValidateAfterSave = { [weak keychain] (corruptedKey: String) in
            keychain?.simulateCorruption(forKey: corruptedKey)
        }

        let result = sut.save(data: data, forKey: key)

        XCTAssertEqual(fallback.receivedSaveKey, key)
        XCTAssertEqual(fallback.receivedSaveData, data)
        assertEventuallyEqual(sut.load(forKey: key), data)
        XCTAssertEqual(result, KeychainSaveResult.success, "Save should succeed with valid input")
    }

    func test_saveData_usesAlternativeStorage_whenKeychainAndFallbackFail() {
        let (sut, keychain, fallback, alternative) = makeDefaultSUT()
        let key = "test-key"
        let data = "test-data".data(using: .utf8)!
        keychain.saveResultToReturn = .failure
        fallback.saveResultToReturn = .failure
        alternative.saveResultToReturn = .success
        keychain.willValidateAfterSave = { [weak keychain] (corruptedKey: String) in
            keychain?.simulateCorruption(forKey: corruptedKey)
        }

        // Simula que Keychain y fallback fallan
        let result = sut.save(data: data, forKey: key)

        XCTAssertEqual(alternative.receivedSaveKey, key)
        XCTAssertEqual(alternative.receivedSaveData, data)
        XCTAssertEqual(result, KeychainSaveResult.success, "Save should succeed with valid input")
    }

    // MARK: - Helpers

    private func makeKeychainFullSpy() -> KeychainFullSpy {
        KeychainFullSpy()
    }

    private func makeDefaultSUT(file: StaticString = #file, line: UInt = #line) -> (KeychainSecureStorage, KeychainFullSpy, KeychainFullSpy, KeychainFullSpy) {
        makeSUT(
            keychain: makeKeychainFullSpy(),
            fallback: makeKeychainFullSpy(),
            alternative: makeKeychainFullSpy(),
            file: file, line: line
        )
    }

    private func makeSUT(
        keychain: KeychainFullSpy,
        fallback: KeychainFullSpy,
        alternative: KeychainFullSpy,
        file: StaticString = #file, line: UInt = #line
    ) -> (KeychainSecureStorage, KeychainFullSpy, KeychainFullSpy, KeychainFullSpy) {
        let sut = KeychainSecureStorage(keychain: keychain, fallback: fallback, alternative: alternative)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(keychain, file: file, line: line)
        trackForMemoryLeaks(fallback, file: file, line: line)
        trackForMemoryLeaks(alternative, file: file, line: line)
        return (sut, keychain, fallback, alternative)
    }
}
