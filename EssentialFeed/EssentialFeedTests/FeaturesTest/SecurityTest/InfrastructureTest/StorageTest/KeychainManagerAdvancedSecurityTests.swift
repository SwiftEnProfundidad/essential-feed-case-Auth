@testable import EssentialFeed
import XCTest

final class KeychainManagerAdvancedSecurityTests: XCTestCase {
    func test_load_whenDecryptionFailsMultipleTimes_attemptsAndFailsGracefully() {
        let (sut, readerSpy, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let key = "failing-decrypt-key"
        let corruptedEncryptedData = "corrupted-encrypted-data".data(using: .utf8)!
        let decryptionError = NSError(domain: "decryption", code: 1)

        readerSpy.loadResult = .success(corruptedEncryptedData)
        encryptorSpy.decryptResult = .failure(decryptionError)

        XCTAssertThrowsError(try sut.load(forKey: key)) { error in
            XCTAssertEqual(error as NSError, decryptionError, "Expected decryption error to be propagated")
        }

        XCTAssertEqual(encryptorSpy.decryptCallCount, 1, "Expected decryption to be attempted")
        XCTAssertEqual(errorHandlerSpy.handledErrors.count, 1, "Expected error to be handled")
        XCTAssertEqual(errorHandlerSpy.handledErrors.first?.operation, "load (decryption failed)", "Expected correct operation description")
    }

    func test_save_whenEncryptionFailsWithSensitiveData_clearsDataFromMemory() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let key = "sensitive-key"
        let sensitiveData = "super-secret-password-123".data(using: .utf8)!
        let encryptionError = NSError(domain: "encryption", code: 2)

        encryptorSpy.encryptResult = .failure(encryptionError)

        XCTAssertThrowsError(try sut.save(data: sensitiveData, forKey: key))

        XCTAssertEqual(writerSpy.saveCallCount, 0, "Expected no save attempt when encryption fails")
        XCTAssertEqual(errorHandlerSpy.handledErrors.count, 1, "Expected error to be handled")
        XCTAssertEqual(encryptorSpy.encryptedData.count, 1, "Expected encryption to be attempted once")
    }

    func test_load_withTamperedKeychainData_detectsAndHandlesCorruption() {
        let (sut, readerSpy, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let key = "tampered-key"
        let tamperedData = Data([0x00, 0xFF, 0x00, 0xFF])
        let corruptionError = createKeychainError(.dataCorruption)

        readerSpy.loadResult = .success(tamperedData)
        encryptorSpy.decryptResult = .failure(corruptionError)

        XCTAssertThrowsError(try sut.load(forKey: key)) { error in
            XCTAssertNotNil(error, "Expected error to be thrown for corrupted data")
        }

        XCTAssertEqual(encryptorSpy.decryptCallCount, 1, "Expected decryption attempt")
        XCTAssertEqual(errorHandlerSpy.handledErrors.count, 1, "Expected error to be handled")
    }

    func test_delete_whenKeyDoesNotExist_handlesGracefullyWithoutError() {
        let (sut, _, writerSpy, _, errorHandlerSpy) = makeSUT()
        let nonExistentKey = "non-existent-key"
        let notFoundError = createKeychainError(.itemNotFound)

        writerSpy.deleteResult = .failure(notFoundError)

        XCTAssertNoThrow(try sut.delete(forKey: nonExistentKey), "Expected graceful handling of non-existent key deletion")

        XCTAssertEqual(writerSpy.deleteCallCount, 1, "Expected delete attempt")
        XCTAssertEqual(errorHandlerSpy.handledErrors.count, 0, "Expected no error handling for item not found")
    }

    func test_encrypt_withLargeData_handlesEfficiently() {
        let (sut, _, writerSpy, encryptorSpy, _) = makeSUT()
        let key = "large-data-key"
        let largeData = Data(repeating: 0x42, count: 1024 * 1024)
        let largeEncryptedData = Data(repeating: 0x24, count: 1024 * 1024 + 64)

        encryptorSpy.encryptResult = .success(largeEncryptedData)
        writerSpy.saveResult = .success(())

        let startTime = CFAbsoluteTimeGetCurrent()
        XCTAssertNoThrow(try sut.save(data: largeData, forKey: key))
        let endTime = CFAbsoluteTimeGetCurrent()

        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 5.0, "Expected large data encryption to complete within 5 seconds")

        XCTAssertEqual(encryptorSpy.encryptCallCount, 1, "Expected encryption to be called once")
        XCTAssertEqual(writerSpy.saveCallCount, 1, "Expected save to be called once")
    }

    func test_concurrentOperations_maintainDataIntegrity() {
        let (sut, readerSpy, writerSpy, encryptorSpy, _) = makeSUT()
        let baseKey = "concurrent-key"
        let testData = "concurrent-test-data".data(using: .utf8)!
        let encryptedData = "encrypted-concurrent-data".data(using: .utf8)!

        encryptorSpy.encryptResult = .success(encryptedData)
        encryptorSpy.decryptResult = .success(testData)
        writerSpy.saveResult = .success(())
        writerSpy.deleteResult = .success(())
        readerSpy.loadResult = .success(encryptedData)

        let operationCount = 10
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = operationCount

        let queue = DispatchQueue.global(qos: .background)

        for i in 0 ..< operationCount {
            queue.async {
                let key = "\(baseKey)-\(i)"

                XCTAssertNoThrow(try sut.save(data: testData, forKey: key))
                XCTAssertNoThrow(try sut.load(forKey: key))
                XCTAssertNoThrow(try sut.delete(forKey: key))

                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        XCTAssertEqual(encryptorSpy.encryptCallCount, operationCount, "Expected all encryptions to complete")
        XCTAssertEqual(encryptorSpy.decryptCallCount, operationCount, "Expected all decryptions to complete")
        XCTAssertEqual(writerSpy.saveCallCount, operationCount, "Expected all saves to complete")
        XCTAssertEqual(writerSpy.deleteCallCount, operationCount, "Expected all deletes to complete")
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
        let migrationManager = KeychainMigrationManager(
            encryptor: encryptorSpy,
            writer: writerSpy,
            errorHandler: errorHandlerSpy
        )

        let sut = KeychainManager(
            reader: readerSpy,
            writer: writerSpy,
            encryptor: encryptorSpy,
            errorHandler: errorHandlerSpy,
            migrationManager: migrationManager
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(readerSpy, file: file, line: line)
        trackForMemoryLeaks(writerSpy, file: file, line: line)
        trackForMemoryLeaks(encryptorSpy, file: file, line: line)
        trackForMemoryLeaks(errorHandlerSpy, file: file, line: line)
        trackForMemoryLeaks(migrationManager, file: file, line: line)

        return (sut, readerSpy, writerSpy, encryptorSpy, errorHandlerSpy)
    }

    private func createKeychainError(_ errorType: KeychainErrorType) -> Error {
        NSError(domain: "KeychainError", code: errorType.rawValue, userInfo: [NSLocalizedDescriptionKey: "Keychain error"])
    }
}

private enum KeychainErrorType: Int {
    case dataCorruption = 1
    case itemNotFound = 2
}
