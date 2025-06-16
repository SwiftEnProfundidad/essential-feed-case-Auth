import EssentialFeed
import XCTest

final class KeychainMigrationManagerAdvancedTests: XCTestCase {
    func test_attemptMigration_withValidPlainTextToken_encryptsAndSavesSuccessfully() {
        let (sut, encryptorSpy, writerSpy, errorHandlerSpy) = makeSUT()
        let key = "legacy-token-key"
        let plainTextToken = "legacy-plain-text-token"
        let plainTextData = plainTextToken.data(using: .utf8)!
        let encryptedData = "encrypted-legacy-token".data(using: .utf8)!

        encryptorSpy.completeEncrypt(with: encryptedData)
        writerSpy.completeSaveSuccessfully()

        let result = try? sut.attemptMigration(for: plainTextData, key: key)

        XCTAssertEqual(result, plainTextData, "Expected migration to return original plain text data")
        XCTAssertEqual(encryptorSpy.receivedMessages.count, 1, "Expected encryption to be called once")
        XCTAssertEqual(encryptorSpy.receivedMessages.first, .encrypt(data: plainTextData), "Expected plain text data to be encrypted")
        XCTAssertEqual(writerSpy.receivedMessages.count, 1, "Expected save to be called once")
        XCTAssertEqual(writerSpy.receivedMessages.first, .save(data: encryptedData, key: key), "Expected encrypted data to be saved with correct key")
        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Expected migration success to be logged")
    }

    func test_attemptMigration_withInvalidData_throwsBadFormatError() {
        let (sut, _, _, errorHandlerSpy) = makeSUT()
        let key = "invalid-data-key"
        let invalidData = Data([0xFF, 0xFE, 0xFD])

        XCTAssertThrowsError(try sut.attemptMigration(for: invalidData, key: key)) { error in
            XCTAssertNotNil(error, "Expected error to be thrown for invalid data")
        }

        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Expected error to be handled")
        if case let .handle(_, _, operation) = errorHandlerSpy.messages.first {
            XCTAssertTrue(operation.contains("migration attempt - bad format"), "Expected bad format operation description")
        } else {
            XCTFail("Expected handle message with operation")
        }
    }

    func test_attemptMigration_whenEncryptionFails_throwsEncryptionError() {
        let (sut, encryptorSpy, _, errorHandlerSpy) = makeSUT()
        let key = "encryption-fail-key"
        let plainTextToken = "valid-plain-text-token"
        let plainTextData = plainTextToken.data(using: .utf8)!
        let encryptionError = NSError(domain: "encryption", code: 1)

        encryptorSpy.completeEncrypt(with: encryptionError)

        XCTAssertThrowsError(try sut.attemptMigration(for: plainTextData, key: key)) { error in
            XCTAssertEqual(error as NSError, encryptionError, "Expected encryption error to be propagated")
        }

        XCTAssertEqual(encryptorSpy.receivedMessages.count, 1, "Expected encryption to be attempted")
        XCTAssertEqual(encryptorSpy.receivedMessages.first, .encrypt(data: plainTextData), "Expected correct data to be encrypted")
        XCTAssertEqual(errorHandlerSpy.messages.count, 0, "Expected no error handling for encryption failure")
    }

    func test_attemptMigration_whenSaveFails_throwsSaveError() {
        let (sut, encryptorSpy, writerSpy, errorHandlerSpy) = makeSUT()
        let key = "save-fail-key"
        let plainTextToken = "valid-plain-text-token"
        let plainTextData = plainTextToken.data(using: .utf8)!
        let encryptedData = "encrypted-token".data(using: .utf8)!
        let saveError = NSError(domain: "save", code: 1)

        encryptorSpy.completeEncrypt(with: encryptedData)
        writerSpy.completeSave(with: saveError)

        XCTAssertThrowsError(try sut.attemptMigration(for: plainTextData, key: key)) { error in
            XCTAssertNotNil(error, "Expected save error to be thrown")
        }

        XCTAssertEqual(encryptorSpy.receivedMessages.count, 1, "Expected encryption to be attempted")
        XCTAssertEqual(encryptorSpy.receivedMessages.first, .encrypt(data: plainTextData), "Expected correct data to be encrypted")
        XCTAssertEqual(writerSpy.receivedMessages.count, 1, "Expected save to be attempted")
        XCTAssertEqual(writerSpy.receivedMessages.first, .save(data: encryptedData, key: key), "Expected encrypted data to be saved")
        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Expected error to be handled")
        if case let .handle(_, _, operation) = errorHandlerSpy.messages.first {
            XCTAssertTrue(operation.contains("migration save failed"), "Expected save failed operation description")
        } else {
            XCTFail("Expected handle message with operation")
        }
    }

    func test_attemptMigration_withEmptyStringData_throwsBadFormatError() {
        let (sut, _, _, errorHandlerSpy) = makeSUT()
        let key = "empty-string-key"
        let emptyStringData = "".data(using: .utf8)!

        XCTAssertThrowsError(try sut.attemptMigration(for: emptyStringData, key: key)) { error in
            XCTAssertNotNil(error, "Expected error to be thrown for empty string")
        }

        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Expected error to be handled")
        if case let .handle(_, _, operation) = errorHandlerSpy.messages.first {
            XCTAssertTrue(operation.contains("converting string back to data"), "Expected conversion error operation description")
        } else {
            XCTFail("Expected handle message with operation")
        }
    }

    func test_attemptMigration_withLargeTokenData_handlesEfficiently() {
        let (sut, encryptorSpy, writerSpy, _) = makeSUT()
        let key = "large-token-key"
        let largeToken = String(repeating: "a", count: 10000)
        let largeTokenData = largeToken.data(using: .utf8)!
        let largeEncryptedData = Data(repeating: 0x42, count: 10064)

        encryptorSpy.completeEncrypt(with: largeEncryptedData)
        writerSpy.completeSaveSuccessfully()

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try? sut.attemptMigration(for: largeTokenData, key: key)
        let endTime = CFAbsoluteTimeGetCurrent()

        let executionTime = endTime - startTime
        XCTAssertNotNil(result, "Expected migration to succeed")
        XCTAssertLessThan(executionTime, 2.0, "Expected large token migration to complete within 2 seconds")
        XCTAssertEqual(encryptorSpy.receivedMessages.count, 1, "Expected encryption to be called once")
        XCTAssertEqual(encryptorSpy.receivedMessages.first, .encrypt(data: largeTokenData), "Expected large data to be encrypted")
        XCTAssertEqual(writerSpy.receivedMessages.count, 1, "Expected save to be called once")
        XCTAssertEqual(writerSpy.receivedMessages.first, .save(data: largeEncryptedData, key: key), "Expected encrypted data to be saved")
    }

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (
        sut: KeychainMigrationManager,
        encryptorSpy: KeychainEncryptorSpy,
        writerSpy: KeychainWriterSpy,
        errorHandlerSpy: KeychainErrorHandlerSpy
    ) {
        let encryptorSpy = KeychainEncryptorSpy()
        let writerSpy = KeychainWriterSpy()
        let errorHandlerSpy = KeychainErrorHandlerSpy()

        let sut = KeychainMigrationManager(
            encryptor: encryptorSpy,
            writer: writerSpy,
            errorHandler: errorHandlerSpy
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(encryptorSpy, file: file, line: line)
        trackForMemoryLeaks(writerSpy, file: file, line: line)
        trackForMemoryLeaks(errorHandlerSpy, file: file, line: line)

        return (sut, encryptorSpy, writerSpy, errorHandlerSpy)
    }
}
