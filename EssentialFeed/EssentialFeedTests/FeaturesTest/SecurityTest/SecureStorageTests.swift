import EssentialFeed
import XCTest

// CU: SystemKeychain
// Checklist: Verify system keychain operations are secure and reliable
final class SecureStorageTests: XCTestCase {
    func test_init_doesNotMessageStoreUponCreation() {
        let (_, store, encryptionService) = makeSUT()

        XCTAssertTrue(store.receivedMessages.isEmpty, "Expected no store messages")
        XCTAssertTrue(encryptionService.encryptedData.isEmpty, "Expected no encryption messages")
        XCTAssertTrue(encryptionService.decryptedData.isEmpty, "Expected no decryption messages")
    }

    func test_protectionLevel_returnsHighForUnreadableData() {
        let (sut, _, _) = makeSUT()
        let invalidData = "invalid".data(using: .utf16)! // Usando UTF16 para que falle al leer como UTF8

        let level = sut.protectionLevel(for: invalidData)

        XCTAssertEqual(level, .high, "Unreadable data should be treated as high protection")
    }

    func test_protectionLevel_returnsHighForSensitiveData() {
        let (sut, _, _) = makeSUT()
        let sensitiveKeywords = ["password123", "token123", "secret_key", "auth_token", "credentials123"]

        for keyword in sensitiveKeywords {
            let data = keyword.data(using: .utf8)!
            let level = sut.protectionLevel(for: data)
            XCTAssertEqual(level, .high, "Expected high protection for sensitive keyword: \(keyword)")
        }
    }

    func test_protectionLevel_returnsMediumForPersonalData() {
        let (sut, _, _) = makeSUT()
        let personalKeywords = ["John Doe", "email@test.com", "phone: 123456", "address: street", "birth: 01/01/2000"]

        for keyword in personalKeywords {
            let data = keyword.data(using: .utf8)!
            let level = sut.protectionLevel(for: data)
            XCTAssertEqual(level, .medium, "Expected medium protection for personal data: \(keyword)")
        }
    }

    func test_protectionLevel_returnsMediumForCapitalizedNames() {
        let (sut, _, _) = makeSUT()
        let data = "John Doe".data(using: .utf8)!

        let level = sut.protectionLevel(for: data)

        XCTAssertEqual(level, .medium, "Expected medium protection for capitalized names")
    }

    func test_protectionLevel_returnsLowForPublicData() {
        let (sut, _, _) = makeSUT()
        let publicData = "welcome message".data(using: .utf8)!

        let level = sut.protectionLevel(for: publicData)

        XCTAssertEqual(level, .low, "Expected low protection for public data")
    }

    func test_save_encryptsAndStoresHighProtectionData() {
        let (sut, store, encryptionService) = makeSUT()
        let sensitiveData = "password123".data(using: .utf8)!
        let key = "secure-key"
        let encrypted = Data(sensitiveData.reversed())

        try? sut.save(sensitiveData, forKey: key)

        XCTAssertEqual(encryptionService.encryptedData, [sensitiveData], "Should encrypt high protection data")
        XCTAssertEqual(store.receivedMessages, [.save(key: key, value: encrypted)], "Should store encrypted data")
    }

    func test_save_encryptsAndStoresMediumProtectionData() {
        let (sut, store, encryptionService) = makeSUT()
        let personalData = "John Doe".data(using: .utf8)!
        let key = "secure-key"
        let encrypted = Data(personalData.reversed())

        try? sut.save(personalData, forKey: key)

        XCTAssertEqual(encryptionService.encryptedData, [personalData], "Should encrypt medium protection data")
        XCTAssertEqual(store.receivedMessages, [.save(key: key, value: encrypted)], "Should store encrypted data")
    }

    func test_save_storesLowProtectionDataWithoutEncryption() {
        let (sut, store, encryptionService) = makeSUT()
        let publicData = "welcome message".data(using: .utf8)!
        let key = "secure-key"

        try? sut.save(publicData, forKey: key)

        XCTAssertTrue(encryptionService.encryptedData.isEmpty, "Should not encrypt low protection data")
        XCTAssertEqual(store.receivedMessages, [.save(key: key, value: publicData)], "Should store unencrypted data")
    }

    func test_save_failsOnEncryptionError() {
        let (sut, store, encryptionService) = makeSUT()
        let sensitiveData = "password123".data(using: .utf8)!
        let encryptionError = NSError(domain: "encryption", code: 0)
        encryptionService.stubbedError = encryptionError

        XCTAssertThrowsError(try sut.save(sensitiveData, forKey: "any-key")) { error in
            XCTAssertEqual(error as NSError, encryptionError)
        }
        XCTAssertTrue(store.receivedMessages.isEmpty, "Should not store data on encryption error")
    }

    func test_save_throwsErrorWhenEncryptionServiceThrowsUnexpectedError() {
        let (sut, store, encryptionService) = makeSUT()
        let data = "password123".data(using: .utf8)!
        let unexpectedError = NSError(domain: "encryption", code: 999)
        encryptionService.stubbedError = unexpectedError

        XCTAssertThrowsError(try sut.save(data, forKey: "any-key")) { error in
            XCTAssertEqual(error as NSError, unexpectedError)
        }
        XCTAssertTrue(store.receivedMessages.isEmpty)
    }

    func test_save_throwsErrorWhenStoreThrowsUnexpectedError() {
        let (sut, store, _) = makeSUT()
        let data = "welcome message".data(using: .utf8)!
        let storeError = NSError(domain: "store", code: 999)
        store.stubSave(forKey: "any-key", with: .failure(storeError))

        XCTAssertThrowsError(try sut.save(data, forKey: "any-key")) { error in
            XCTAssertEqual(error as NSError, storeError)
        }
    }

    func test_save_withEmptyData_savesWithLowProtection() {
        let (sut, store, encryptionService) = makeSUT()
        let emptyData = Data()
        let key = "empty-key"

        try? sut.save(emptyData, forKey: key)

        XCTAssertTrue(encryptionService.encryptedData.isEmpty, "Should not encrypt empty data")
        XCTAssertEqual(store.receivedMessages, [.save(key: key, value: emptyData)], "Should store empty data as low protection")
    }

    func test_save_failsOnStoreError() {
        let (sut, store, _) = makeSUT()
        let publicData = "welcome message".data(using: .utf8)!
        let storeError = NSError(domain: "store", code: 0)

        store.stubSave(forKey: "any-key", with: .failure(storeError))

        XCTAssertThrowsError(try sut.save(publicData, forKey: "any-key")) { error in
            XCTAssertEqual(error as NSError, storeError)
        }
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (
        sut: SecureStorage,
        store: SecureStoreSpy,
        encryptionService: EncryptionServiceSpy
    ) {
        let store = SecureStoreSpy()
        let encryptionService = EncryptionServiceSpy()
        let sut = SecureStorage(store: store, encryptionService: encryptionService)
        trackForMemoryLeaks(store, file: file, line: line)
        trackForMemoryLeaks(encryptionService, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, store, encryptionService)
    }
}
