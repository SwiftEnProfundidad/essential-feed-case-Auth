@testable import EssentialFeed

// Existing imports
import XCTest

// // TODO: Create Spies for KeychainReader, KeychainWriter, KeychainEncryptor
// // They should be placed in EssentialFeedTests/FeaturesTest/SecurityTest/Helpers/

final class KeychainManagerTests: XCTestCase {
    let systemKey = "com.essentialfeed.test.keychain.integration.key-\(UUID().uuidString)"
    let systemData = "SensitiveValue-🟢-\(UUID().uuidString)".data(using: .utf8)!
    let systemData2 = "SecondValue-🔴-\(UUID().uuidString)".data(using: .utf8)!

    override func tearDown() {
        super.tearDown()
        _ = SystemKeychain().delete(forKey: systemKey)
    }

    func test_example_placeholder() {
        XCTFail("Tests for KeychainManager need to be implemented.")
    }

    func test_save_load_and_delete_with_system_keychain() {
        let sut = makeSystemSUT()
        let saveResult = sut.save(data: systemData, forKey: systemKey)
        XCTAssertEqual(saveResult, .success, "Should succeed saving data into system keychain")

        guard let loaded = sut.load(forKey: systemKey) else {
            XCTFail("Expected to load data for \(systemKey), got nil")
            return
        }
        XCTAssertEqual(loaded, systemData, "Loaded data must match the data saved")

        let deleteResult = sut.delete(forKey: systemKey)
        XCTAssertTrue(deleteResult, "Should succeed deleting data from system keychain")

        let shouldBeNil = sut.load(forKey: systemKey)
        XCTAssertNil(shouldBeNil, "Should be nil after deleting from keychain")
    }

    func test_delete_returns_false_for_nonexistent_key() {
        let sut = makeSystemSUT()
        let result = sut.delete(forKey: UUID().uuidString)
        XCTAssertFalse(result, "Delete should return false when the key does not exist")
    }

    func test_save_overwrites_existing_data() {
        let sut = makeSystemSUT()
        XCTAssertEqual(sut.save(data: systemData, forKey: systemKey), .success)
        XCTAssertEqual(sut.save(data: systemData2, forKey: systemKey), .success)
        let loaded = sut.load(forKey: systemKey)
        XCTAssertEqual(loaded, systemData2, "Should load latest value after overwrite")
        XCTAssertTrue(sut.delete(forKey: systemKey))
        XCTAssertNil(sut.load(forKey: systemKey))
    }

    func test_save_empty_data_returns_failure() {
        let sut = makeSystemSUT()
        XCTAssertEqual(sut.save(data: Data(), forKey: systemKey), .failure, "Saving empty data should fail")
    }

    func test_save_empty_key_returns_failure() {
        let sut = makeSystemSUT()
        XCTAssertEqual(sut.save(data: systemData, forKey: ""), .failure, "Saving with empty key should fail")
    }

    // MARK: - Helpers

    private func makeSUT(
        reader: KeychainReader = KeychainReaderSpy(),
        writer: KeychainWriter = KeychainWriterSpy(),
        encryptor: KeychainEncryptor = KeychainEncryptorSpy(),
        errorHandler: KeychainErrorHandlerSpy = KeychainErrorHandlerSpy(),
        file _: StaticString = #filePath,
        line _: UInt = #line
    ) -> (sut: KeychainManager, readerSpy: KeychainReaderSpy, writerSpy: KeychainWriterSpy, encryptorSpy: KeychainEncryptorSpy, errorHandlerSpy: KeychainErrorHandlerSpy) {
        let readerSpy = reader as! KeychainReaderSpy
        let writerSpy = writer as! KeychainWriterSpy
        let encryptorSpy = encryptor as! KeychainEncryptorSpy

        let sut = KeychainManager(
            reader: readerSpy,
            writer: writerSpy,
            encryptor: encryptorSpy,
            errorHandler: errorHandler
        )

        // trackForMemoryLeaks(sut, file: file, line: line)
        // trackForMemoryLeaks(readerSpy, file: file, line: line)
        // trackForMemoryLeaks(writerSpy, file: file, line: line)
        // trackForMemoryLeaks(encryptorSpy, file: file, line: line)
        // trackForMemoryLeaks(errorHandler, file: file, line: line)

        return (sut, readerSpy, writerSpy, encryptorSpy, errorHandler)
    }

    func makeSystemSUT() -> SystemKeychain {
        let sut = SystemKeychain()
        trackForMemoryLeaks(sut)
        return sut
    }
}
