import EssentialFeed
import XCTest

final class KeychainManagerTests: XCTestCase {
    func test_load_whenReaderThrowsError_notifiesHandlerAndRethrowsError() {
        let (sut, readerSpy, _, _, errorHandlerSpy) = makeSUT()
        let expectedError = KeychainError.itemNotFound
        let testKey = "anyKeyLoadError"

        readerSpy.completeLoad(with: expectedError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.load(forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Should rethrow the exact error from KeychainReader")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: testKey, operation: "load (decrypt)")], "Should notify error handler with correct error details")
        XCTAssertEqual(readerSpy.receivedMessages, [.load(key: testKey)], "Should call reader with correct key")
    }

    func test_load_whenReaderSucceeds_returnsDataAndDoesNotNotifyHandler() {
        let (sut, readerSpy, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("any data load success".utf8)
        let encryptedData = Data("encrypted data load success".utf8)
        let testKey = "anyKeyLoadSuccess"

        readerSpy.completeLoad(with: encryptedData)
        encryptorSpy.completeDecrypt(with: plainData)

        var capturedData: Data?
        XCTAssertNoThrow(capturedData = try sut.load(forKey: testKey), "Should not throw when reader and decryptor succeed")

        XCTAssertEqual(capturedData, plainData, "Should return decrypted plain data")
        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Should not notify error handler on successful operation")
        XCTAssertEqual(readerSpy.receivedMessages, [.load(key: testKey)], "Should call reader with correct key")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.decrypt(data: encryptedData)], "Should decrypt the data from reader")
    }

    func test_load_whenReaderThrowsGenericError_notifiesHandlerWithUnhandledErrorAndRethrowsGenericError() {
        let (sut, readerSpy, _, _, errorHandlerSpy) = makeSUT()
        let testKey = "anyKeyLoadGenericError"
        let genericError = NSError(domain: "LoadGenericErrorDomain", code: 123, userInfo: nil)

        readerSpy.completeLoad(with: genericError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.load(forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertIdentical(capturedError as NSError?, genericError, "Should rethrow the original generic error")
        let expectedKeychainError = KeychainError.unhandledError(-1)
        XCTAssertEqual(errorHandlerSpy.receivedMessages.count, 1, "Should notify error handler exactly once")
        if let firstMessage = errorHandlerSpy.receivedMessages.first {
            if case let .handled(error: reportedError, key: reportedKey, operation: reportedOperation) = firstMessage {
                XCTAssertEqual(reportedError, expectedKeychainError, "Should report unhandled error type to handler")
                XCTAssertEqual(reportedKey, testKey, "Should report correct key to error handler")
                XCTAssertEqual(reportedOperation, "load (decrypt) - unexpected error type", "Should indicate unexpected error type in operation description")
            } else {
                XCTFail("Error handler should receive handled message type")
            }
        } else {
            XCTFail("Error handler should be notified when generic error occurs")
        }
        XCTAssertEqual(readerSpy.receivedMessages, [.load(key: testKey)], "Should call reader with correct key")
    }

    // MARK: - Save Tests

    func test_save_whenEncryptorFails_notifiesHandlerAndRethrowsError() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let testData = Data("any data save encryptor fail".utf8)
        let testKey = "anyKeySaveEncryptorFail"
        let expectedError = KeychainError.dataConversionFailed

        encryptorSpy.completeEncrypt(with: expectedError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.save(data: testData, forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Should rethrow encryption error")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: testKey, operation: "save")], "Should notify error handler about encryption failure")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: testData)], "Should attempt to encrypt provided data")
    }

    func test_save_whenWriterFails_notifiesHandlerAndRethrowsError() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("plain data save writer fail".utf8)
        let encryptedData = Data("encrypted data save writer fail".utf8)
        let testKey = "anyKeySaveWriterFail"
        let expectedError = KeychainError.duplicateItem

        encryptorSpy.completeEncrypt(with: encryptedData)
        writerSpy.completeSave(with: expectedError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.save(data: plainData, forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Should rethrow writer error")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: testKey, operation: "save")], "Should notify error handler about writer failure")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: plainData)], "Should encrypt data before attempting to write")
        XCTAssertEqual(writerSpy.receivedMessages, [.save(data: encryptedData, key: testKey)], "Should attempt to save encrypted data")
    }

    func test_save_whenEncryptionAndWriteSucceed_doesNotNotifyHandler() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("plain data save success".utf8)
        let encryptedData = Data("encrypted data save success".utf8)
        let testKey = "anyKeySaveSuccess"

        encryptorSpy.completeEncrypt(with: encryptedData)
        writerSpy.completeSaveSuccessfully()

        XCTAssertNoThrow(try sut.save(data: plainData, forKey: testKey), "Should not throw when encryption and writing succeed")

        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Should not notify error handler on successful operation")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: plainData)], "Should encrypt provided data")
        XCTAssertEqual(writerSpy.receivedMessages, [.save(data: encryptedData, key: testKey)], "Should save encrypted data with correct key")
    }

    // MARK: - Delete Tests

    func test_delete_whenWriterThrowsError_notifiesHandlerAndRethrowsError() {
        let (sut, _, writerSpy, _, errorHandlerSpy) = makeSUT()
        let testKey = "anyKeyDeleteError"
        let expectedError = KeychainError.itemNotFound

        writerSpy.completeDelete(with: expectedError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.delete(forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Should rethrow deletion error")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: testKey, operation: "delete")], "Should notify error handler about deletion failure")
        XCTAssertEqual(writerSpy.receivedMessages, [.delete(key: testKey)], "Should attempt to delete with correct key")
    }

    func test_delete_whenWriterSucceeds_doesNotNotifyHandler() {
        let (sut, _, writerSpy, _, errorHandlerSpy) = makeSUT()
        let testKey = "anyKeyDeleteSuccess"

        writerSpy.completeDeleteSuccessfully()

        XCTAssertNoThrow(try sut.delete(forKey: testKey), "Should not throw when deletion succeeds")

        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Should not notify error handler on successful deletion")
        XCTAssertEqual(writerSpy.receivedMessages, [.delete(key: testKey)], "Should delete with correct key")
    }

    // MARK: - Encrypt Tests (Standalone)

    func test_encrypt_whenEncryptorThrowsError_notifiesHandlerAndRethrowsError() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let testData = Data("plain data encrypt error".utf8)
        let expectedError = KeychainError.dataConversionFailed

        encryptorSpy.completeEncrypt(with: expectedError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.encrypt(testData)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Should rethrow encryption error")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: nil, operation: "encrypt")], "Should notify error handler about standalone encryption failure")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: testData)], "Should attempt to encrypt provided data")
    }

    func test_encrypt_whenEncryptorSucceeds_returnsDataAndDoesNotNotifyHandler() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("plain data encrypt success".utf8)
        let expectedEncryptedData = Data("encrypted data encrypt success".utf8)

        encryptorSpy.completeEncrypt(with: expectedEncryptedData)

        var capturedData: Data?
        XCTAssertNoThrow(capturedData = try sut.encrypt(plainData), "Should not throw when encryption succeeds")

        XCTAssertEqual(capturedData, expectedEncryptedData, "Should return encrypted data from encryptor")
        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Should not notify error handler on successful standalone encryption")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: plainData)], "Should encrypt provided data")
    }

    // MARK: - Decrypt Tests (Standalone)

    func test_decrypt_whenEncryptorThrowsError_notifiesHandlerAndRethrowsError() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let encryptedData = Data("encrypted data decrypt error".utf8)
        let expectedError = KeychainError.decryptionFailed

        encryptorSpy.completeDecrypt(with: expectedError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.decrypt(encryptedData)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Should rethrow decryption error")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: nil, operation: "decrypt")], "Should notify error handler about standalone decryption failure")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.decrypt(data: encryptedData)], "Should attempt to decrypt provided data")
    }

    func test_decrypt_whenEncryptorSucceeds_returnsDataAndDoesNotNotifyHandler() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let encryptedData = Data("encrypted data decrypt success".utf8)
        let expectedPlainData = Data("plain data decrypt success".utf8)

        encryptorSpy.completeDecrypt(with: expectedPlainData)

        var capturedData: Data?
        XCTAssertNoThrow(capturedData = try sut.decrypt(encryptedData), "Should not throw when decryption succeeds")

        XCTAssertEqual(capturedData, expectedPlainData, "Should return decrypted plain data")
        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Should not notify error handler on successful standalone decryption")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.decrypt(data: encryptedData)], "Should decrypt provided data")
    }

    // MARK: - Migration Tests

    func test_load_whenMigrationOccursButEncryptorFailsToEncrypt_failsWithMigrationError() {
        let (sut, readerSpy, _, encryptorSpy, _) = makeSUT()
        let testKey = "migrationEncryptFailKey"
        let plainTextTokenData = Data("old-plain-text-token".utf8)
        let encryptionError = KeychainError.dataConversionFailed

        readerSpy.completeLoad(with: plainTextTokenData)
        encryptorSpy.completeDecrypt(with: KeychainError.decryptionFailed)
        encryptorSpy.completeEncrypt(with: encryptionError)

        XCTAssertThrowsError(try sut.load(forKey: testKey)) { error in
            XCTAssertEqual(error as? KeychainError, KeychainError.migrationFailedSaveError(encryptionError), "Should throw migration failed save error with the encryption error")
        }
    }

    func test_load_whenMigrationSucceeds_returnsOriginalData() {
        let (sut, readerSpy, writerSpy, encryptorSpy, _) = makeSUT()
        let testKey = "migrationSuccessKey"
        let plainTextTokenData = Data("old-plain-text-token".utf8)
        let encryptedData = Data("encrypted-data".utf8)

        readerSpy.completeLoad(with: plainTextTokenData)
        encryptorSpy.completeDecrypt(with: KeychainError.decryptionFailed)
        encryptorSpy.completeEncrypt(with: encryptedData)
        writerSpy.completeSaveSuccessfully()

        var returnedData: Data?
        XCTAssertNoThrow(returnedData = try sut.load(forKey: testKey), "Should not throw during successful migration")

        XCTAssertEqual(returnedData, plainTextTokenData, "Should return original plain text data after successful migration")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.decrypt(data: plainTextTokenData), .encrypt(data: plainTextTokenData)], "Should attempt decrypt then encrypt for migration")
        XCTAssertEqual(writerSpy.receivedMessages, [.save(data: encryptedData, key: testKey)], "Should save encrypted version during migration")
    }

    // MARK: - Additional Tests for Complete Coverage

    func test_load_whenReaderReturnsNil_returnsNilAndDoesNotNotifyHandler() {
        let (sut, readerSpy, _, _, errorHandlerSpy) = makeSUT()
        let testKey = "anyKeyReturnsNil"

        readerSpy.completeLoad(with: nil)

        var capturedData: Data?
        XCTAssertNoThrow(capturedData = try sut.load(forKey: testKey), "Should not throw when reader returns nil")

        XCTAssertNil(capturedData, "Should return nil when reader returns nil")
        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Should not notify error handler when reader returns nil")
        XCTAssertEqual(readerSpy.receivedMessages, [.load(key: testKey)], "Should call reader with correct key")
    }

    func test_load_whenDecryptionSucceedsAfterFirstFailure_returnsDecryptedData() {
        let (sut, readerSpy, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let encryptedData = Data("encrypted-data".utf8)
        let decryptedData = Data("decrypted-data".utf8)
        let testKey = "anyKeyDecryptAfterFailure"

        readerSpy.completeLoad(with: encryptedData)
        encryptorSpy.completeDecrypt(with: decryptedData)

        var capturedData: Data?
        XCTAssertNoThrow(capturedData = try sut.load(forKey: testKey), "Should not throw when decryption succeeds")

        XCTAssertEqual(capturedData, decryptedData, "Should return decrypted data")
        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Should not notify error handler on successful decryption")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.decrypt(data: encryptedData)], "Should attempt to decrypt the data")
    }

    func test_load_whenMigrationManagerThrowsStringConversionError_propagatesError() {
        let (sut, readerSpy, _, encryptorSpy, _) = makeSUT()
        let testKey = "migrationStringConversionErrorKey"
        let invalidData = Data([0xFF, 0xFE, 0xFD]) // Invalid UTF-8 data

        readerSpy.completeLoad(with: invalidData)
        encryptorSpy.completeDecrypt(with: KeychainError.decryptionFailed)

        XCTAssertThrowsError(try sut.load(forKey: testKey)) { error in
            XCTAssertEqual(error as? KeychainError, KeychainError.migrationFailedBadFormat, "Should throw migration failed bad format error")
        }

        XCTAssertEqual(encryptorSpy.receivedMessages, [.decrypt(data: invalidData)], "Should attempt to decrypt before migration")
    }

    func test_save_whenEncryptionAndWritingSucceed_completesSuccessfully() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("test-save-data".utf8)
        let encryptedData = Data("encrypted-test-save-data".utf8)
        let testKey = "testSaveSuccessKey"

        encryptorSpy.completeEncrypt(with: encryptedData)
        writerSpy.completeSaveSuccessfully()

        XCTAssertNoThrow(try sut.save(data: plainData, forKey: testKey), "Should not throw when encryption and writing succeed")

        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Should not notify error handler on successful operation")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: plainData)], "Should encrypt the provided data")
        XCTAssertEqual(writerSpy.receivedMessages, [.save(data: encryptedData, key: testKey)], "Should save encrypted data with correct key")
    }

    func test_save_whenGenericErrorOccurs_notifiesHandlerWithUnexpectedError() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("test-generic-error-data".utf8)
        let encryptedData = Data("encrypted-generic-error-data".utf8)
        let testKey = "testGenericErrorKey"
        let genericError = NSError(domain: "TestErrorDomain", code: 999, userInfo: nil)

        encryptorSpy.completeEncrypt(with: encryptedData)
        writerSpy.completeSave(with: genericError)

        XCTAssertThrowsError(try sut.save(data: plainData, forKey: testKey)) { error in
            XCTAssertIdentical(error as NSError?, genericError, "Should rethrow the original generic error")
        }

        XCTAssertEqual(errorHandlerSpy.receivedMessages.count, 1, "Should notify error handler exactly once")
        if let firstMessage = errorHandlerSpy.receivedMessages.first {
            if case let .handled(error: reportedError, key: reportedKey, operation: reportedOperation) = firstMessage {
                XCTAssertEqual(reportedError, KeychainError.unhandledError(-1), "Should report unhandled error type to handler")
                XCTAssertEqual(reportedKey, testKey, "Should report correct key to error handler")
                XCTAssertEqual(reportedOperation, "save - unexpected error type", "Should indicate unexpected error type in operation description")
            } else {
                XCTFail("Error handler should receive handled message type")
            }
        }
    }

    func test_delete_whenGenericErrorOccurs_notifiesHandlerWithUnexpectedError() {
        let (sut, _, writerSpy, _, errorHandlerSpy) = makeSUT()
        let testKey = "testDeleteGenericErrorKey"
        let genericError = NSError(domain: "DeleteErrorDomain", code: 888, userInfo: nil)

        writerSpy.completeDelete(with: genericError)

        XCTAssertThrowsError(try sut.delete(forKey: testKey)) { error in
            XCTAssertIdentical(error as NSError?, genericError, "Should rethrow the original generic error")
        }

        XCTAssertEqual(errorHandlerSpy.receivedMessages.count, 1, "Should notify error handler exactly once")
        if let firstMessage = errorHandlerSpy.receivedMessages.first {
            if case let .handled(error: reportedError, key: reportedKey, operation: reportedOperation) = firstMessage {
                XCTAssertEqual(reportedError, KeychainError.unhandledError(-1), "Should report unhandled error type to handler")
                XCTAssertEqual(reportedKey, testKey, "Should report correct key to error handler")
                XCTAssertEqual(reportedOperation, "delete - unexpected error type", "Should indicate unexpected error type in operation description")
            } else {
                XCTFail("Error handler should receive handled message type")
            }
        }
    }

    func test_encrypt_whenGenericErrorOccurs_notifiesHandlerWithUnexpectedError() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let testData = Data("test-encrypt-generic-error".utf8)
        let genericError = NSError(domain: "EncryptErrorDomain", code: 777, userInfo: nil)

        encryptorSpy.completeEncrypt(with: genericError)

        XCTAssertThrowsError(try sut.encrypt(testData)) { error in
            XCTAssertIdentical(error as NSError?, genericError, "Should rethrow the original generic error")
        }

        XCTAssertEqual(errorHandlerSpy.receivedMessages.count, 1, "Should notify error handler exactly once")
        if let firstMessage = errorHandlerSpy.receivedMessages.first {
            if case let .handled(error: reportedError, key: reportedKey, operation: reportedOperation) = firstMessage {
                XCTAssertEqual(reportedError, KeychainError.unhandledError(-1), "Should report unhandled error type to handler")
                XCTAssertNil(reportedKey, "Should report nil key for standalone encryption")
                XCTAssertEqual(reportedOperation, "encrypt - unexpected error type", "Should indicate unexpected error type in operation description")
            } else {
                XCTFail("Error handler should receive handled message type")
            }
        }
    }

    func test_decrypt_whenGenericErrorOccurs_notifiesHandlerWithUnexpectedError() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let testData = Data("test-decrypt-generic-error".utf8)
        let genericError = NSError(domain: "DecryptErrorDomain", code: 666, userInfo: nil)

        encryptorSpy.completeDecrypt(with: genericError)

        XCTAssertThrowsError(try sut.decrypt(testData)) { error in
            XCTAssertIdentical(error as NSError?, genericError, "Should rethrow the original generic error")
        }

        XCTAssertEqual(errorHandlerSpy.receivedMessages.count, 1, "Should notify error handler exactly once")
        if let firstMessage = errorHandlerSpy.receivedMessages.first {
            if case let .handled(error: reportedError, key: reportedKey, operation: reportedOperation) = firstMessage {
                XCTAssertEqual(reportedError, KeychainError.unhandledError(-1), "Should report unhandled error type to handler")
                XCTAssertNil(reportedKey, "Should report nil key for standalone decryption")
                XCTAssertEqual(reportedOperation, "decrypt - unexpected error type", "Should indicate unexpected error type in operation description")
            } else {
                XCTFail("Error handler should receive handled message type")
            }
        }
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
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
