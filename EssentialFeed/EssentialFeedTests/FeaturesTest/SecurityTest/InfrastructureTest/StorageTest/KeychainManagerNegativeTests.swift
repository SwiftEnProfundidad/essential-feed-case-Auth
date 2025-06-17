import EssentialFeed
import XCTest

final class KeychainManagerNegativeTests: XCTestCase {
    func test_load_whenKeychainAccessDenied_propagatesAccessDeniedError() {
        let (sut, readerSpy, _, _, errorHandlerSpy) = makeSUT()
        let testKey = "access-denied-key"
        let accessDeniedError = KeychainError.interactionNotAllowed

        readerSpy.completeLoad(with: accessDeniedError, forKey: testKey)

        XCTAssertThrowsError(try sut.load(forKey: testKey)) { error in
            XCTAssertEqual(error as? KeychainError, .interactionNotAllowed, "Should propagate access denied error")
        }

        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Should handle the access denied error")
        if case let .handle(error, key, operation) = errorHandlerSpy.messages.first {
            XCTAssertEqual(error, .interactionNotAllowed, "Should handle correct error type")
            XCTAssertEqual(key, testKey, "Should handle with correct key")
            XCTAssertEqual(operation, "load", "Should indicate load operation")
        } else {
            XCTFail("Expected handle message with access denied error")
        }
    }

    func test_save_whenEncryptionFailsWithCorruptedData_handlesGracefully() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let testKey = "encryption-failure-key"
        let corruptedData = Data([0xFF, 0xFE, 0xFD, 0xFC])
        let encryptionError = KeychainError.dataConversionFailed

        encryptorSpy.completeEncrypt(with: encryptionError)

        XCTAssertThrowsError(try sut.save(data: corruptedData, forKey: testKey)) { error in
            XCTAssertEqual(error as? KeychainError, .dataConversionFailed, "Should propagate encryption failure")
        }

        XCTAssertEqual(writerSpy.saveCallCount, 0, "Should not attempt save when encryption fails")
        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Should handle encryption error")
        if case let .handle(error, key, operation) = errorHandlerSpy.messages.first {
            XCTAssertEqual(error, .dataConversionFailed, "Should handle encryption failure error")
            XCTAssertEqual(key, testKey, "Should handle with correct key")
            XCTAssertEqual(operation, "save", "Should indicate save operation")
        } else {
            XCTFail("Expected handle message with encryption failure")
        }
    }

    func test_save_whenWriterThrowsUnexpectedSystemError_handlesUnexpectedError() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let testKey = "system-error-key"
        let testData = Data("test-data".utf8)
        let encryptedData = Data("encrypted-test-data".utf8)
        let systemError = NSError(domain: "SystemError", code: -1001, userInfo: [NSLocalizedDescriptionKey: "System failure"])

        encryptorSpy.completeEncrypt(with: encryptedData)
        writerSpy.completeSave(with: systemError, forKey: testKey)

        XCTAssertThrowsError(try sut.save(data: testData, forKey: testKey)) { error in
            XCTAssertEqual((error as NSError).domain, "SystemError", "Should propagate system error")
            XCTAssertEqual((error as NSError).code, -1001, "Should propagate correct error code")
        }

        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Should handle unexpected error")
        if case let .handleUnexpectedError(key, operation) = errorHandlerSpy.messages.first {
            XCTAssertEqual(key, testKey, "Should handle with correct key")
            XCTAssertEqual(operation, "save", "Should indicate save operation")
        } else {
            XCTFail("Expected handleUnexpectedError message")
        }
    }

    func test_load_whenMigrationFailsWithStringConversionError_propagatesError() {
        let (sut, readerSpy, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let testKey = "migration-string-error-key"
        let invalidUTF8Data = Data([0xFF, 0xFE, 0xFD])

        readerSpy.completeLoad(with: invalidUTF8Data, forKey: testKey)
        encryptorSpy.completeDecrypt(with: KeychainError.decryptionFailed)

        XCTAssertThrowsError(try sut.load(forKey: testKey)) { error in
            XCTAssertEqual(error as? KeychainError, .migrationFailedBadFormat, "Should fail migration with bad format error")
        }

        XCTAssertTrue(errorHandlerSpy.messages.contains { message in
            if case let .handle(error, _, _) = message {
                return error == .migrationFailedBadFormat
            }
            return false
        }, "Should handle migration bad format error")
    }

    func test_delete_whenWriterThrowsItemNotFoundError_propagatesError() {
        let (sut, _, writerSpy, _, errorHandlerSpy) = makeSUT()
        let nonExistentKey = "non-existent-key"
        let itemNotFoundError = KeychainError.itemNotFound

        writerSpy.completeDelete(with: itemNotFoundError, forKey: nonExistentKey)

        XCTAssertThrowsError(try sut.delete(forKey: nonExistentKey)) { error in
            XCTAssertEqual(error as? KeychainError, .itemNotFound, "Should propagate item not found error")
        }

        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Should handle item not found error")
        if case let .handle(error, key, operation) = errorHandlerSpy.messages.first {
            XCTAssertEqual(error, .itemNotFound, "Should handle correct error type")
            XCTAssertEqual(key, nonExistentKey, "Should handle with correct key")
            XCTAssertEqual(operation, "delete", "Should indicate delete operation")
        } else {
            XCTFail("Expected handle message with item not found error")
        }
    }

    func test_save_whenKeyContainsOnlyWhitespace_throwsInvalidKeyFormatError() {
        let (sut, _, _, _, errorHandlerSpy) = makeSUT()
        let whitespaceKey = "   \t\n   "
        let testData = Data("test-data".utf8)

        XCTAssertThrowsError(try sut.save(data: testData, forKey: whitespaceKey)) { error in
            XCTAssertEqual(error as? KeychainError, .invalidKeyFormat, "Should throw invalid key format for whitespace-only key")
        }

        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Should handle invalid key format error")
        if case let .handle(error, key, operation) = errorHandlerSpy.messages.first {
            XCTAssertEqual(error, .invalidKeyFormat, "Should handle invalid key format error")
            XCTAssertEqual(key, whitespaceKey, "Should handle with the whitespace key")
            XCTAssertTrue(operation.contains("save"), "Should indicate save operation")
        } else {
            XCTFail("Expected handle message with invalid key format error")
        }
    }

    func test_load_whenKeyContainsOnlyWhitespace_throwsInvalidKeyFormatError() {
        let (sut, _, _, _, errorHandlerSpy) = makeSUT()
        let whitespaceKey = "   \t\n   "

        XCTAssertThrowsError(try sut.load(forKey: whitespaceKey)) { error in
            XCTAssertEqual(error as? KeychainError, .invalidKeyFormat, "Should throw invalid key format for whitespace-only key")
        }

        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Should handle invalid key format error")
        if case let .handle(error, key, operation) = errorHandlerSpy.messages.first {
            XCTAssertEqual(error, .invalidKeyFormat, "Should handle invalid key format error")
            XCTAssertEqual(key, whitespaceKey, "Should handle with the whitespace key")
            XCTAssertTrue(operation.contains("load"), "Should indicate load operation")
        } else {
            XCTFail("Expected handle message with invalid key format error")
        }
    }

    func test_delete_whenKeyContainsOnlyWhitespace_throwsInvalidKeyFormatError() {
        let (sut, _, _, _, errorHandlerSpy) = makeSUT()
        let whitespaceKey = "   \t\n   "

        XCTAssertThrowsError(try sut.delete(forKey: whitespaceKey)) { error in
            XCTAssertEqual(error as? KeychainError, .invalidKeyFormat, "Should throw invalid key format for whitespace-only key")
        }

        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Should handle invalid key format error")
        if case let .handle(error, key, operation) = errorHandlerSpy.messages.first {
            XCTAssertEqual(error, .invalidKeyFormat, "Should handle invalid key format error")
            XCTAssertEqual(key, whitespaceKey, "Should handle with the whitespace key")
            XCTAssertTrue(operation.contains("delete"), "Should indicate delete operation")
        } else {
            XCTFail("Expected handle message with invalid key format error")
        }
    }

    func test_load_whenDecryptionFailsWithCorruptionDetected_handlesSecurely() {
        let (sut, readerSpy, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let testKey = "corruption-detected-key"
        let potentiallyCorruptedData = Data([0x42, 0x42, 0x42, 0x00, 0xFF, 0xFF])
        let corruptionError = KeychainError.decryptionFailed

        readerSpy.completeLoad(with: potentiallyCorruptedData, forKey: testKey)
        encryptorSpy.completeDecrypt(with: corruptionError)

        XCTAssertThrowsError(try sut.load(forKey: testKey)) { error in
            XCTAssertNotNil(error, "Should throw error for corrupted data")
        }

        XCTAssertGreaterThanOrEqual(errorHandlerSpy.messages.count, 1, "Should handle corruption detection")
        let hasDecryptionError = errorHandlerSpy.messages.contains { message in
            if case let .handle(error, _, _) = message {
                return error == .decryptionFailed || error == .migrationFailedBadFormat
            }
            return false
        }
        XCTAssertTrue(hasDecryptionError, "Should handle decryption failure or migration failure")
    }

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (
        sut: KeychainManager,
        readerSpy: KeychainReaderSpy,
        writerSpy: KeychainWriterSpy,
        encryptorSpy: KeychainEncryptorSpy,
        errorHandlerSpy: KeychainErrorHandlerSpy
    ) {
        let readerSpy = KeychainReaderSpy()
        let writerSpy = KeychainWriterSpy()
        let encryptorSpy = KeychainEncryptorSpy()
        let errorHandlerSpy = KeychainErrorHandlerSpy()

        let sut = KeychainManager(
            reader: readerSpy,
            writer: writerSpy,
            encryptor: encryptorSpy,
            errorHandler: errorHandlerSpy
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(readerSpy, file: file, line: line)
        trackForMemoryLeaks(writerSpy, file: file, line: line)
        trackForMemoryLeaks(encryptorSpy, file: file, line: line)
        trackForMemoryLeaks(errorHandlerSpy, file: file, line: line)

        return (sut, readerSpy, writerSpy, encryptorSpy, errorHandlerSpy)
    }
}
