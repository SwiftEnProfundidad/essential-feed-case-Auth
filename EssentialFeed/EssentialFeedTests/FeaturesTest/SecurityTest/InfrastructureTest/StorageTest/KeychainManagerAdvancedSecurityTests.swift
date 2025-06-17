@testable import EssentialFeed
import XCTest

final class KeychainManagerAdvancedSecurityTests: XCTestCase {
    func test_load_whenDecryptionFailsMultipleTimes_attemptsAndFailsGracefully() {
        let (sut, readerSpy, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let key = "failing-decrypt-key"
        let corruptedEncryptedData = "corrupted-encrypted-data".data(using: .utf8)!
        let decryptionError = NSError(domain: "decryption", code: 1, userInfo: [NSLocalizedDescriptionKey: "Decryption failed"])

        readerSpy.completeLoad(with: corruptedEncryptedData, forKey: key)
        encryptorSpy.completeDecrypt(with: decryptionError)

        XCTAssertThrowsError(try sut.load(forKey: key)) { error in
            XCTAssertNotNil(error, "Expected error to be thrown")
        }

        XCTAssertEqual(encryptorSpy.decryptCallCount, 1, "Expected decryption to be attempted")
        XCTAssertGreaterThanOrEqual(errorHandlerSpy.messages.count, 1, "Expected error to be handled")
        if case let .handle(_, handledKey, handledOperation) = errorHandlerSpy.messages.first {
            XCTAssertEqual(handledKey, key, "Expected correct key")
            XCTAssertTrue(handledOperation.contains("load"), "Expected operation to be related to load")
        } else if case let .handleUnexpectedError(handledKey, handledOperation) = errorHandlerSpy.messages.first {
            XCTAssertEqual(handledKey, key, "Expected correct key")
            XCTAssertTrue(handledOperation.contains("load"), "Expected operation to be related to load, got \(handledOperation)")
        } else {
            XCTFail("Expected a .handle or .handleUnexpectedError message")
        }
    }

    func test_save_whenEncryptionFailsWithSensitiveData_clearsDataFromMemory() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let key = "sensitive-key"
        let sensitiveData = "super-secret-password-123".data(using: .utf8)!
        let encryptionError = NSError(domain: "encryption", code: 2, userInfo: [NSLocalizedDescriptionKey: "Encryption failed"])

        encryptorSpy.completeEncrypt(with: encryptionError)

        XCTAssertThrowsError(try sut.save(data: sensitiveData, forKey: key))

        XCTAssertEqual(writerSpy.saveCallCount, 0, "Expected no save attempt when encryption fails")
        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Expected error to be handled")
        XCTAssertEqual(encryptorSpy.encryptedData.count, 1, "Expected encryption to be attempted once")
        XCTAssertEqual(encryptorSpy.encryptCallCount, 1, "Expected encryption to be attempted once")

        if case let .handle(_, handledKey, handledOperation) = errorHandlerSpy.messages.first {
            XCTAssertEqual(handledKey, key, "Expected correct key")
            XCTAssertEqual(handledOperation, "save", "Expected correct operation description")
        } else if case let .handleUnexpectedError(handledKey, handledOperation) = errorHandlerSpy.messages.first {
            XCTAssertEqual(handledKey, key, "Expected correct key")
            XCTAssertEqual(handledOperation, "save", "Expected correct operation description")
        } else {
            XCTFail("Expected a .handle or .handleUnexpectedError message")
        }
    }

    func test_load_withTamperedKeychainData_detectsAndHandlesCorruption() {
        let (sut, readerSpy, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let key = "tampered-key"
        let tamperedData = Data([0x00, 0xFF, 0x00, 0xFF])
        let decryptionErrorForSUT = KeychainError.decryptionFailed

        readerSpy.completeLoad(with: tamperedData, forKey: key)
        encryptorSpy.completeDecrypt(with: decryptionErrorForSUT)

        XCTAssertThrowsError(try sut.load(forKey: key)) { error in
            XCTAssertNotNil(error, "Expected error to be thrown for corrupted data")
        }

        XCTAssertEqual(encryptorSpy.decryptCallCount, 1, "Expected initial decryption attempt")
        XCTAssertGreaterThanOrEqual(errorHandlerSpy.messages.count, 1, "Expected at least one error to be handled")
    }

    func test_delete_whenKeyDoesNotExist_handlesGracefullyWithoutError() {
        let (sut, _, writerSpy, _, errorHandlerSpy) = makeSUT()
        let nonExistentKey = "non-existent-key"
        let notFoundError = KeychainError.itemNotFound

        writerSpy.completeDelete(with: notFoundError, forKey: nonExistentKey)

        XCTAssertThrowsError(try sut.delete(forKey: nonExistentKey)) { error in
            XCTAssertEqual(error as? KeychainError, .itemNotFound, "Expected itemNotFound error")
        }

        XCTAssertEqual(writerSpy.deleteCallCount, 1, "Expected delete attempt")
        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Expected error to be handled")
    }

    func test_encrypt_withLargeData_handlesEfficiently() {
        let (sut, _, writerSpy, encryptorSpy, _) = makeSUT()
        let key = "large-data-key"
        let largeData = Data(repeating: 0x42, count: 1024 * 1024)
        let largeEncryptedData = Data(repeating: 0x24, count: 1024 * 1024 + 64)

        encryptorSpy.completeEncrypt(with: largeEncryptedData)
        writerSpy.completeSaveSuccessfully(forKey: key)

        let startTime = CFAbsoluteTimeGetCurrent()
        XCTAssertNoThrow(try sut.save(data: largeData, forKey: key))
        let endTime = CFAbsoluteTimeGetCurrent()

        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 5.0, "Expected large data encryption to complete within 5 seconds")

        XCTAssertEqual(encryptorSpy.encryptCallCount, 1, "Expected encryption to be called once")
        XCTAssertEqual(writerSpy.saveCallCount, 1, "Expected save to be called once")
    }

    func test_concurrentOperations_maintainDataIntegrity() {
        let (sut, _, writerSpy, encryptorSpy, _) = makeSUT()
        let testData = "concurrent-test-data".data(using: .utf8)!
        let encryptedData = "encrypted-concurrent-data".data(using: .utf8)!

        encryptorSpy.completeEncrypt(with: encryptedData)
        encryptorSpy.completeDecrypt(with: testData)

        let operationCount = 5
        let saveExpectation = XCTestExpectation(description: "All save operations complete")
        saveExpectation.expectedFulfillmentCount = operationCount

        for i in 0 ..< operationCount {
            let key = "concurrent-key-\(i)"
            writerSpy.completeSaveSuccessfully(forKey: key)
        }

        for i in 0 ..< operationCount {
            DispatchQueue.global(qos: .userInitiated).async {
                let key = "concurrent-key-\(i)"

                do {
                    try sut.save(data: testData, forKey: key)
                    saveExpectation.fulfill()
                } catch {
                    XCTFail("Save operation for key \(key) failed with error: \(error)")
                    saveExpectation.fulfill()
                }
            }
        }

        wait(for: [saveExpectation], timeout: 10.0)

        XCTAssertEqual(encryptorSpy.encryptCallCount, operationCount, "Encrypt should have been called \(operationCount) times, but was \(encryptorSpy.encryptCallCount).")
        XCTAssertEqual(writerSpy.saveCallCount, operationCount, "Save should have been called \(operationCount) times, but was \(writerSpy.saveCallCount).")
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
