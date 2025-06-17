import EssentialFeed
import XCTest

final class KeychainManagerTests: XCTestCase {
    func test_load_whenReaderThrowsError_notifiesHandlerAndRethrowsError() {
        let (sut, readerSpy, _, _, errorHandlerSpy) = makeSUT()
        let expectedError = KeychainError.itemNotFound
        let testKey = "anyKeyLoadError"

        readerSpy.completeLoad(with: expectedError, forKey: testKey)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.load(forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Should rethrow the exact error from KeychainReader")
        XCTAssertEqual(errorHandlerSpy.messages, [.handle(error: expectedError, key: testKey, operation: "load")], "Should notify error handler with correct error details")
        XCTAssertEqual(readerSpy.receivedMessages, [.load(key: testKey)], "Should call reader with correct key")
    }

    func test_load_whenReaderSucceeds_returnsDataAndDoesNotNotifyHandler() {
        let (sut, readerSpy, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("any data load success".utf8)
        let encryptedData = Data("encrypted data load success".utf8)
        let testKey = "anyKeyLoadSuccess"

        readerSpy.completeLoad(with: encryptedData, forKey: testKey)
        encryptorSpy.completeDecrypt(with: plainData)

        var capturedData: Data?
        XCTAssertNoThrow(capturedData = try sut.load(forKey: testKey), "Should not throw when reader and decryptor succeed")

        XCTAssertEqual(capturedData, plainData, "Should return decrypted plain data")
        XCTAssertTrue(errorHandlerSpy.messages.isEmpty, "Should not notify error handler on successful operation")
        XCTAssertEqual(readerSpy.receivedMessages, [.load(key: testKey)], "Should call reader with correct key")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.decrypt(data: encryptedData)], "Should decrypt the data from reader")
    }

    func test_load_whenReaderThrowsGenericError_notifiesHandlerWithUnhandledErrorAndRethrowsGenericError() {
        let (sut, readerSpy, _, _, errorHandlerSpy) = makeSUT()
        let testKey = "anyKeyLoadGenericError"
        let genericError = NSError(domain: "LoadGenericErrorDomain", code: 123, userInfo: nil)

        readerSpy.completeLoad(with: genericError, forKey: testKey)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.load(forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertIdentical(capturedError as NSError?, genericError, "Should rethrow the original generic error")
        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Should notify error handler exactly once")
        if let firstMessage = errorHandlerSpy.messages.first {
            if case let .handleUnexpectedError(key: reportedKey, operation: reportedOperation) = firstMessage {
                XCTAssertEqual(reportedKey, testKey, "Should report correct key to error handler")
                XCTAssertEqual(reportedOperation, "load", "Should indicate load operation")
            } else {
                XCTFail("Error handler should receive handleUnexpectedError message type")
            }
        } else {
            XCTFail("Error handler should be notified when generic error occurs")
        }
        XCTAssertEqual(readerSpy.receivedMessages, [.load(key: testKey)], "Should call reader with correct key")
    }

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
        XCTAssertEqual(errorHandlerSpy.messages, [.handle(error: expectedError, key: testKey, operation: "save")], "Should notify error handler about encryption failure")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: testData)], "Should attempt to encrypt provided data")
    }

    func test_save_whenWriterFails_notifiesHandlerAndRethrowsError() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("plain data save writer fail".utf8)
        let encryptedData = Data("encrypted data save writer fail".utf8)
        let testKey = "anyKeySaveWriterFail"
        let expectedError = KeychainError.duplicateItem

        encryptorSpy.completeEncrypt(with: encryptedData)
        writerSpy.completeSave(with: expectedError, forKey: testKey)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.save(data: plainData, forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Should rethrow writer error")
        XCTAssertEqual(errorHandlerSpy.messages, [.handle(error: expectedError, key: testKey, operation: "save")], "Should notify error handler about writer failure")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: plainData)], "Should encrypt data before attempting to write")
        XCTAssertEqual(writerSpy.receivedMessages, [.save(data: encryptedData, key: testKey)], "Should attempt to save encrypted data")
    }

    func test_save_whenEncryptionAndWriteSucceed_doesNotNotifyHandler() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("plain data save success".utf8)
        let encryptedData = Data("encrypted data save success".utf8)
        let testKey = "anyKeySaveSuccess"

        encryptorSpy.completeEncrypt(with: encryptedData)
        writerSpy.completeSaveSuccessfully(forKey: testKey)

        XCTAssertNoThrow(try sut.save(data: plainData, forKey: testKey), "Should not throw when encryption and writing succeed")

        XCTAssertTrue(errorHandlerSpy.messages.isEmpty, "Should not notify error handler on successful operation")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: plainData)], "Should encrypt provided data")
        XCTAssertEqual(writerSpy.receivedMessages, [.save(data: encryptedData, key: testKey)], "Should save encrypted data with correct key")
    }

    func test_delete_whenWriterThrowsError_notifiesHandlerAndRethrowsError() {
        let (sut, _, writerSpy, _, errorHandlerSpy) = makeSUT()
        let testKey = "anyKeyDeleteError"
        let expectedError = KeychainError.itemNotFound

        writerSpy.completeDelete(with: expectedError, forKey: testKey)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.delete(forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Should rethrow deletion error")
        XCTAssertEqual(errorHandlerSpy.messages, [.handle(error: expectedError, key: testKey, operation: "delete")], "Should notify error handler about deletion failure")
        XCTAssertEqual(writerSpy.receivedMessages, [.delete(key: testKey)], "Should attempt to delete with correct key")
    }

    func test_delete_whenWriterSucceeds_doesNotNotifyHandler() {
        let (sut, _, writerSpy, _, errorHandlerSpy) = makeSUT()
        let testKey = "anyKeyDeleteSuccess"

        writerSpy.completeDeleteSuccessfully(forKey: testKey)

        XCTAssertNoThrow(try sut.delete(forKey: testKey), "Should not throw when deletion succeeds")

        XCTAssertTrue(errorHandlerSpy.messages.isEmpty, "Should not notify error handler on successful deletion")
        XCTAssertEqual(writerSpy.receivedMessages, [.delete(key: testKey)], "Should delete with correct key")
    }

    func test_load_whenKeyIsEmpty_throwsInvalidKeyFormatErrorAndNotifiesHandler() {
        let (sut, readerSpy, _, _, errorHandlerSpy) = makeSUT()
        let emptyKey = ""

        XCTAssertThrowsError(try sut.load(forKey: emptyKey)) { error in
            XCTAssertEqual(error as? KeychainError, .invalidKeyFormat, "Should throw invalidKeyFormat for empty key")
        }

        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Error handler should be notified once")
        if case let .handle(error, key, operation) = errorHandlerSpy.messages.first {
            XCTAssertEqual(error, .invalidKeyFormat, "Error handler should be notified of invalidKeyFormat")
            XCTAssertEqual(key, emptyKey, "Error handler should receive the empty key")
            XCTAssertTrue(operation.contains("load (empty key)"), "Operation description should indicate load with empty key")
        } else {
            XCTFail("Error handler message not in expected format. Got: \(String(describing: errorHandlerSpy.messages.first))")
        }
        XCTAssertTrue(readerSpy.receivedMessages.isEmpty, "Reader should not be called when key is empty")
    }

    func test_save_whenKeyIsEmpty_throwsInvalidKeyFormatErrorAndNotifiesHandler() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let emptyKey = ""
        let testData = Data("anyData".utf8)

        XCTAssertThrowsError(try sut.save(data: testData, forKey: emptyKey)) { error in
            XCTAssertEqual(error as? KeychainError, .invalidKeyFormat, "Should throw invalidKeyFormat for empty key")
        }

        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Error handler should be notified once")
        if case let .handle(error, key, operation) = errorHandlerSpy.messages.first {
            XCTAssertEqual(error, .invalidKeyFormat, "Error handler should be notified of invalidKeyFormat")
            XCTAssertEqual(key, emptyKey, "Error handler should receive the empty key")
            XCTAssertTrue(operation.contains("save (empty key)"), "Operation description should indicate save with empty key")
        } else {
            XCTFail("Error handler message not in expected format. Got: \(String(describing: errorHandlerSpy.messages.first))")
        }
        XCTAssertTrue(encryptorSpy.receivedMessages.isEmpty, "Encryptor should not be called when key is empty")
        XCTAssertTrue(writerSpy.receivedMessages.isEmpty, "Writer should not be called when key is empty")
    }

    func test_delete_whenKeyIsEmpty_throwsInvalidKeyFormatErrorAndNotifiesHandler() {
        let (sut, _, writerSpy, _, errorHandlerSpy) = makeSUT()
        let emptyKey = ""

        XCTAssertThrowsError(try sut.delete(forKey: emptyKey)) { error in
            XCTAssertEqual(error as? KeychainError, .invalidKeyFormat, "Should throw invalidKeyFormat for empty key")
        }

        XCTAssertEqual(errorHandlerSpy.messages.count, 1, "Error handler should be notified once")
        if case let .handle(error, key, operation) = errorHandlerSpy.messages.first {
            XCTAssertEqual(error, .invalidKeyFormat, "Error handler should be notified of invalidKeyFormat")
            XCTAssertEqual(key, emptyKey, "Error handler should receive the empty key")
            XCTAssertTrue(operation.contains("delete (empty key)"), "Operation description should indicate delete with empty key")
        } else {
            XCTFail("Error handler message not in expected format. Got: \(String(describing: errorHandlerSpy.messages.first))")
        }
        XCTAssertTrue(writerSpy.receivedMessages.isEmpty, "Writer should not be called when key is empty")
    }

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
