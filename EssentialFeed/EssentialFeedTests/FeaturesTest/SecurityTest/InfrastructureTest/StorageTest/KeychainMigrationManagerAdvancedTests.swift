@testable import EssentialFeed
import XCTest

final class KeychainMigrationManagerAdvancedTests: XCTestCase {
    func test_attemptMigration_whenReaderThrowsError_throwsErrorAndHandles() {
        let (_, encryptorSpyLocal, writerSpy, errorHandlerSpy) = makeSUT()
        let key = "reader-error-key"

        let plainData = "some data".data(using: .utf8)!
        encryptorSpyLocal.completeEncrypt(with: Data("encrypted".utf8))
        let saveErrorDuringMigration = KeychainError.duplicateItem
        writerSpy.completeSave(with: saveErrorDuringMigration, forKey: key)

        let migrationManager = KeychainMigrationManager(encryptor: encryptorSpyLocal, writer: writerSpy, errorHandler: errorHandlerSpy)

        XCTAssertThrowsError(try migrationManager.attemptMigration(for: plainData, key: key)) { error in
            XCTAssertEqual(error as? KeychainError, .migrationFailedSaveError(saveErrorDuringMigration), "Expected migration save error")
        }
        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Expected error to be handled")
    }

    func test_attemptMigration_whenEncryptionFails_throwsEncryptionError() {
        let (sut, encryptorSpy, _, errorHandlerSpy) = makeSUT()
        let key = "encryption-fail-key"
        let plainTextToken = "valid-plain-text-token"
        let plainTextData = plainTextToken.data(using: .utf8)!
        let encryptionError = NSError(domain: "encryption", code: 1)

        encryptorSpy.completeEncrypt(with: encryptionError)

        XCTAssertThrowsError(try sut.attemptMigration(for: plainTextData, key: key)) { error in
            if case let .migrationFailedSaveError(underlyingError) = error as? KeychainError {
                XCTAssertEqual(underlyingError as NSError, encryptionError, "Expected underlying encryption error")
            } else {
                XCTFail("Expected KeychainError.migrationFailedSaveError with underlying encryption error")
            }
        }

        XCTAssertEqual(encryptorSpy.receivedMessages.count, 1, "Expected encryption to be attempted")
        XCTAssertEqual(encryptorSpy.receivedMessages.first, .encrypt(data: plainTextData), "Expected correct data to be encrypted")
        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Expected error to be handled")
    }

    func test_attemptMigration_whenSaveFails_throwsSaveError() {
        let (sut, encryptorSpy, writerSpy, errorHandlerSpy) = makeSUT()
        let key = "save-fail-key"
        let plainTextToken = "valid-plain-text-token"
        let plainTextData = plainTextToken.data(using: .utf8)!
        let encryptedData = "encrypted-token".data(using: .utf8)!
        let saveError = NSError(domain: "save", code: 1)

        encryptorSpy.completeEncrypt(with: encryptedData)
        writerSpy.completeSave(with: saveError, forKey: key)

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

    func test_attemptMigration_withEmptyStringData_succeedsWithEmptyData() {
        let (sut, encryptorSpy, writerSpy, errorHandlerSpy) = makeSUT()
        let key = "empty-string-key"
        let emptyStringData = "".data(using: .utf8)!
        let encryptedEmptyData = "encrypted-empty".data(using: .utf8)!

        encryptorSpy.completeEncrypt(with: encryptedEmptyData)
        writerSpy.completeSaveSuccessfully(forKey: key)

        let result = try? sut.attemptMigration(for: emptyStringData, key: key)

        XCTAssertEqual(result, emptyStringData, "Expected migration to succeed with empty data")
        XCTAssertEqual(encryptorSpy.receivedMessages.count, 1, "Expected encryption to be called")
        XCTAssertEqual(writerSpy.receivedMessages.count, 1, "Expected save to be called")
        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Expected migration success to be logged")
    }

    func test_attemptMigration_withLargeTokenData_handlesEfficiently() {
        let (sut, encryptorSpy, writerSpy, _) = makeSUT()
        let key = "large-token-key"
        let largeToken = String(repeating: "a", count: 10000)
        let largeTokenData = largeToken.data(using: .utf8)!
        let largeEncryptedData = Data(repeating: 0x42, count: 10064)

        encryptorSpy.completeEncrypt(with: largeEncryptedData)
        writerSpy.completeSaveSuccessfully(forKey: key)

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try? sut.attemptMigration(for: largeTokenData, key: key)
        let endTime = CFAbsoluteTimeGetCurrent()

        let executionTime = endTime - startTime
        XCTAssertNotNil(result, "Expected migration to succeed")
        XCTAssertLessThan(executionTime, 2.0, "Expected large token migration to complete within 2 seconds")
        XCTAssertEqual(encryptorSpy.receivedMessages.count, 1, "Expected encryption to be called once")
        XCTAssertEqual(writerSpy.receivedMessages.count, 1, "Expected save to be called once")
    }

    func test_attemptMigration_whenKeyIsEmpty_throwsError() {
        let (sut, _, _, errorHandlerSpy) = makeSUT()
        let data = Data("anyData".utf8)
        let emptyKey = ""

        XCTAssertThrowsError(try sut.attemptMigration(for: data, key: emptyKey)) { error in
            XCTAssertEqual(error as? KeychainError, KeychainError.invalidKeyFormat)
        }
        XCTAssertEqual(errorHandlerSpy.messages.count, 1)
        if case let .handle(error, key, operation) = errorHandlerSpy.messages.first {
            XCTAssertEqual(error, .invalidKeyFormat)
            XCTAssertEqual(key, emptyKey)
            XCTAssertTrue(operation.contains("migration attempt - empty key"))
        } else {
            XCTFail("Expected specific error handling for empty key")
        }
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
