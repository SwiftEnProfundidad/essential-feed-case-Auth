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

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Expected load to rethrow the same error from reader.")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: testKey, operation: "load")])
        XCTAssertEqual(readerSpy.receivedMessages, [.load(key: testKey)])
    }

    func test_load_whenReaderSucceeds_returnsDataAndDoesNotNotifyHandler() {
        let (sut, readerSpy, _, _, errorHandlerSpy) = makeSUT()
        let expectedData = Data("any data load success".utf8)
        let testKey = "anyKeyLoadSuccess"

        readerSpy.completeLoad(with: expectedData)

        var capturedData: Data?
        XCTAssertNoThrow(capturedData = try sut.load(forKey: testKey))

        XCTAssertEqual(capturedData, expectedData, "Expected load to return the same data from reader.")
        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Expected errorHandler not to be notified on success.")
        XCTAssertEqual(readerSpy.receivedMessages, [.load(key: testKey)])
    }

    func test_load_whenReaderThrowsGenericNsError_notifiesHandlerWithUnhandledErrorAndRethrowsGenericError() {
        let (sut, readerSpy, _, _, errorHandlerSpy) = makeSUT()
        let testKey = "anyKeyLoadGenericError"
        let genericError = NSError(domain: "LoadGenericErrorDomain", code: 123, userInfo: nil)

        readerSpy.completeLoad(with: genericError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.load(forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertIdentical(capturedError as NSError?, genericError, "Expected load to rethrow the same generic NSError from reader.")

        let expectedKeychainError = KeychainError.unhandledError(status: -1)
        XCTAssertEqual(errorHandlerSpy.receivedMessages.count, 1, "Expected one message to errorHandler.")
        if let firstMessage = errorHandlerSpy.receivedMessages.first {
            if case let .handled(error: reportedError, key: reportedKey, operation: reportedOperation) = firstMessage {
                XCTAssertEqual(reportedError, expectedKeychainError, "Error mismatch in errorHandler.")
                XCTAssertEqual(reportedKey, testKey, "Key mismatch in errorHandler.")
                XCTAssertEqual(reportedOperation, "load - unexpected error type", "Operation mismatch in errorHandler.")
            } else {
                XCTFail("Unexpected message type from errorHandler: \(firstMessage)")
            }
        } else {
            XCTFail("ErrorHandler was not notified.")
        }

        XCTAssertEqual(readerSpy.receivedMessages, [.load(key: testKey)])
    }

    // MARK: - Save Tests

    func test_save_whenEncryptorFails_notifiesHandlerAndRethrowsError() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let testData = Data("any data save encryptor fail".utf8)
        let testKey = "anyKeySaveEncryptorFail"
        let expectedError = KeychainError.encryptionFailed

        encryptorSpy.completeEncrypt(with: expectedError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.save(data: testData, forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Expected save to rethrow the same error from encryptor.")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: testKey, operation: "save")])
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: testData)])
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

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Expected save to rethrow the same error from writer.")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: testKey, operation: "save")])
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: plainData)])
        XCTAssertEqual(writerSpy.receivedMessages, [.save(data: encryptedData, key: testKey)])
    }

    func test_save_whenEncryptionAndWriteSucceed_doesNotNotifyHandler() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("plain data save success".utf8)
        let encryptedData = Data("encrypted data save success".utf8)
        let testKey = "anyKeySaveSuccess"

        encryptorSpy.completeEncrypt(with: encryptedData)
        writerSpy.completeSaveSuccessfully()

        XCTAssertNoThrow(try sut.save(data: plainData, forKey: testKey), "Expected save to not throw an error.")

        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Expected errorHandler not to be notified on success.")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: plainData)])
        XCTAssertEqual(writerSpy.receivedMessages, [.save(data: encryptedData, key: testKey)])
    }

    func test_save_whenEncryptorThrowsGenericNsError_duringSave_notifiesHandlerWithUnhandledErrorAndRethrowsGenericError() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("plain data save encryptor generic fail".utf8)
        let testKey = "anyKeySaveEncryptorGenericFail"
        let genericEncryptionError = NSError(domain: "EncryptDuringSaveDomain", code: 999, userInfo: nil)

        encryptorSpy.completeEncrypt(with: genericEncryptionError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.save(data: plainData, forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertIdentical(capturedError as NSError?, genericEncryptionError, "Expected save to rethrow the same generic NSError from encryptor.")

        let expectedKeychainError = KeychainError.unhandledError(status: -1)
        XCTAssertEqual(errorHandlerSpy.receivedMessages.count, 1, "Expected one message to errorHandler.")
        if let firstMessage = errorHandlerSpy.receivedMessages.first {
            if case let .handled(error: reportedError, key: reportedKey, operation: reportedOperation) = firstMessage {
                XCTAssertEqual(reportedError, expectedKeychainError, "Error mismatch in errorHandler.")
                XCTAssertEqual(reportedKey, testKey, "Key mismatch in errorHandler.")
                XCTAssertEqual(reportedOperation, "save - unexpected error type", "Operation mismatch in errorHandler.")
            } else {
                XCTFail("Unexpected message type from errorHandler: \(firstMessage)")
            }
        } else {
            XCTFail("ErrorHandler was not notified.")
        }

        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: plainData)])
        XCTAssertTrue(writerSpy.receivedMessages.isEmpty, "Expected writer not to be called if encryptor fails during save.")
    }

    func test_save_whenWriterThrowsGenericNsError_notifiesHandlerWithUnhandledErrorAndRethrowsGenericError() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("plain data save writer generic fail".utf8)
        let encryptedData = Data("encrypted data save writer generic fail".utf8)
        let testKey = "anyKeySaveWriterGenericFail"
        let genericError = NSError(domain: "WriterGenericErrorDomain", code: 189, userInfo: nil)

        encryptorSpy.completeEncrypt(with: encryptedData)
        writerSpy.completeSave(with: genericError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.save(data: plainData, forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertIdentical(capturedError as NSError?, genericError, "Expected save to rethrow the same generic NSError from writer.")

        let expectedKeychainError = KeychainError.unhandledError(status: -1)
        XCTAssertEqual(errorHandlerSpy.receivedMessages.count, 1, "Expected one message to errorHandler.")
        if let firstMessage = errorHandlerSpy.receivedMessages.first {
            if case let .handled(error: reportedError, key: reportedKey, operation: reportedOperation) = firstMessage {
                XCTAssertEqual(reportedError, expectedKeychainError, "Error mismatch in errorHandler.")
                XCTAssertEqual(reportedKey, testKey, "Key mismatch in errorHandler.")
                XCTAssertEqual(reportedOperation, "save - unexpected error type", "Operation mismatch in errorHandler.")
            } else {
                XCTFail("Unexpected message type from errorHandler: \(firstMessage)")
            }
        } else {
            XCTFail("ErrorHandler was not notified.")
        }

        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: plainData)])
        XCTAssertEqual(writerSpy.receivedMessages, [.save(data: encryptedData, key: testKey)])
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

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Expected delete to rethrow the same error from writer.")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: testKey, operation: "delete")])
        XCTAssertEqual(writerSpy.receivedMessages, [.delete(key: testKey)])
    }

    func test_delete_whenWriterSucceeds_doesNotNotifyHandler() {
        let (sut, _, writerSpy, _, errorHandlerSpy) = makeSUT()
        let testKey = "anyKeyDeleteSuccess"

        writerSpy.completeDeleteSuccessfully()

        XCTAssertNoThrow(try sut.delete(forKey: testKey), "Expected delete to not throw an error.")

        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Expected errorHandler not to be notified on success.")
        XCTAssertEqual(writerSpy.receivedMessages, [.delete(key: testKey)])
    }

    func test_delete_whenWriterThrowsGenericNsError_notifiesHandlerWithUnhandledErrorAndRethrowsGenericError() {
        let (sut, _, writerSpy, _, errorHandlerSpy) = makeSUT()
        let testKey = "anyKeyDeleteGenericError"
        let genericError = NSError(domain: "DeleteGenericErrorDomain", code: 789, userInfo: nil)

        writerSpy.completeDelete(with: genericError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.delete(forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertIdentical(capturedError as NSError?, genericError, "Expected delete to rethrow the same generic NSError from writer.")

        let expectedKeychainError = KeychainError.unhandledError(status: -1)
        XCTAssertEqual(errorHandlerSpy.receivedMessages.count, 1, "Expected one message to errorHandler.")
        if let firstMessage = errorHandlerSpy.receivedMessages.first {
            if case let .handled(error: reportedError, key: reportedKey, operation: reportedOperation) = firstMessage {
                XCTAssertEqual(reportedError, expectedKeychainError, "Error mismatch in errorHandler.")
                XCTAssertEqual(reportedKey, testKey, "Key mismatch in errorHandler.")
                XCTAssertEqual(reportedOperation, "delete - unexpected error type", "Operation mismatch in errorHandler.")
            } else {
                XCTFail("Unexpected message type from errorHandler: \(firstMessage)")
            }
        } else {
            XCTFail("ErrorHandler was not notified.")
        }

        XCTAssertEqual(writerSpy.receivedMessages, [.delete(key: testKey)])
    }

    // MARK: - Encrypt Tests (Standalone)

    func test_encrypt_whenEncryptorThrowsError_notifiesHandlerAndRethrowsError() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let testData = Data("plain data encrypt error".utf8)
        let expectedError = KeychainError.encryptionFailed

        encryptorSpy.completeEncrypt(with: expectedError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.encrypt(testData)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Expected encrypt to rethrow error from encryptor.")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: nil, operation: "encrypt")])
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: testData)])
    }

    func test_encrypt_whenEncryptorSucceeds_returnsDataAndDoesNotNotifyHandler() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("plain data encrypt success".utf8)
        let expectedEncryptedData = Data("encrypted data encrypt success".utf8)

        encryptorSpy.completeEncrypt(with: expectedEncryptedData)

        var capturedData: Data?
        XCTAssertNoThrow(capturedData = try sut.encrypt(plainData))

        XCTAssertEqual(capturedData, expectedEncryptedData, "Expected encrypt to return data from encryptor.")
        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Expected no errorHandler notification on encrypt success.")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: plainData)])
    }

    func test_encrypt_whenEncryptorThrowsGenericNsError_notifiesHandlerWithUnhandledErrorAndRethrowsGenericError() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let testData = Data("plain data encrypt generic error".utf8)
        let genericError = NSError(domain: "EncryptGenericErrorDomain", code: 101, userInfo: nil)

        encryptorSpy.completeEncrypt(with: genericError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.encrypt(testData)) { error in
            capturedError = error
        }

        XCTAssertIdentical(capturedError as NSError?, genericError)
        let expectedKeychainError = KeychainError.unhandledError(status: -1)
        XCTAssertEqual(errorHandlerSpy.receivedMessages.count, 1)
        if let firstMessage = errorHandlerSpy.receivedMessages.first {
            if case let .handled(error: reportedError, key: reportedKey, operation: reportedOperation) = firstMessage {
                XCTAssertEqual(reportedError, expectedKeychainError)
                XCTAssertNil(reportedKey)
                XCTAssertEqual(reportedOperation, "encrypt - unexpected error type")
            } else { XCTFail("Unexpected errorHandler message: \(firstMessage)") }
        } else { XCTFail("ErrorHandler not notified") }

        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: testData)])
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

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Expected decrypt to rethrow error from encryptor.")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: nil, operation: "decrypt")])
        XCTAssertEqual(encryptorSpy.receivedMessages, [.decrypt(data: encryptedData)])
    }

    func test_decrypt_whenEncryptorSucceeds_returnsDataAndDoesNotNotifyHandler() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let encryptedData = Data("encrypted data decrypt success".utf8)
        let expectedPlainData = Data("plain data decrypt success".utf8)

        encryptorSpy.completeDecrypt(with: expectedPlainData)

        var capturedData: Data?
        XCTAssertNoThrow(capturedData = try sut.decrypt(encryptedData))

        XCTAssertEqual(capturedData, expectedPlainData, "Expected decrypt to return data from encryptor.")
        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Expected no errorHandler notification on decrypt success.")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.decrypt(data: encryptedData)])
    }

    func test_decrypt_whenEncryptorThrowsGenericNsError_notifiesHandlerWithUnhandledErrorAndRethrowsGenericError() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let testData = Data("encrypted data decrypt generic error".utf8)
        let genericError = NSError(domain: "DecryptGenericErrorDomain", code: 202, userInfo: nil)

        encryptorSpy.completeDecrypt(with: genericError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.decrypt(testData)) { error in
            capturedError = error
        }

        XCTAssertIdentical(capturedError as NSError?, genericError)
        let expectedKeychainError = KeychainError.unhandledError(status: -1)
        XCTAssertEqual(errorHandlerSpy.receivedMessages.count, 1)
        if let firstMessage = errorHandlerSpy.receivedMessages.first {
            if case let .handled(error: reportedError, key: reportedKey, operation: reportedOperation) = firstMessage {
                XCTAssertEqual(reportedError, expectedKeychainError)
                XCTAssertNil(reportedKey)
                XCTAssertEqual(reportedOperation, "decrypt - unexpected error type")
            } else { XCTFail("Unexpected errorHandler message: \(firstMessage)") }
        } else { XCTFail("ErrorHandler not notified") }

        XCTAssertEqual(encryptorSpy.receivedMessages, [.decrypt(data: testData)])
    }

    // MARK: - Helpers

    private func makeSUT(
        reader: KeychainReader = KeychainReaderSpy(),
        writer: KeychainWriter = KeychainWriterSpy(),
        encryptor: KeychainEncryptor = KeychainEncryptorSpy(),
        errorHandler: KeychainErrorHandler = KeychainErrorHandlerSpy(),
        file _: StaticString = #filePath,
        line _: UInt = #line
    ) -> (sut: KeychainManager, readerSpy: KeychainReaderSpy, writerSpy: KeychainWriterSpy, encryptorSpy: KeychainEncryptorSpy, errorHandlerSpy: KeychainErrorHandlerSpy) {
        let readerSpyCasted = reader as! KeychainReaderSpy
        let writerSpyCasted = writer as! KeychainWriterSpy
        let encryptorSpyCasted = encryptor as! KeychainEncryptorSpy
        let errorHandlerSpyCasted = errorHandler as! KeychainErrorHandlerSpy

        let sut = KeychainManager(
            reader: readerSpyCasted,
            writer: writerSpyCasted,
            encryptor: encryptorSpyCasted,
            errorHandler: errorHandlerSpyCasted
        )

        trackForMemoryLeaks(sut, file: #file, line: #line)
        trackForMemoryLeaks(readerSpyCasted, file: #file, line: #line)
        trackForMemoryLeaks(writerSpyCasted, file: #file, line: #line)
        trackForMemoryLeaks(encryptorSpyCasted, file: #file, line: #line)
        trackForMemoryLeaks(errorHandlerSpyCasted, file: #file, line: #line)

        return (sut, readerSpyCasted, writerSpyCasted, encryptorSpyCasted, errorHandlerSpyCasted)
    }
}
