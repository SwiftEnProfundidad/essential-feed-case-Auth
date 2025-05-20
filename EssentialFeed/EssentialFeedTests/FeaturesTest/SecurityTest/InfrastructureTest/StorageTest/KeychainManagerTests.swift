import EssentialFeed
import XCTest

final class KeychainManagerTests: XCTestCase {
    func test_load_whenReaderThrowsError_notifiesHandlerAndRethrowsError() {
        let (sut, readerSpy, _, _, errorHandlerSpy) = makeSUT()
        let expectedError = KeychainError.itemNotFound
        let testKey = "anyKey"

        readerSpy.completeLoad(with: expectedError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.load(forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Expected load to rethrow the same error from reader.")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: testKey, operation: "load")], "Expected errorHandler to be notified with correct error, key, and operation.")
        XCTAssertEqual(readerSpy.receivedMessages, [.load(key: testKey)], "Expected load to be called on reader with the correct key.")
    }

    func test_load_whenReaderSucceeds_returnsDataAndDoesNotNotifyHandler() {
        let (sut, readerSpy, _, _, errorHandlerSpy) = makeSUT()
        let expectedData = Data("any data".utf8)
        let testKey = "anyKey"

        readerSpy.completeLoad(with: expectedData)

        var capturedData: Data?
        XCTAssertNoThrow(capturedData = try sut.load(forKey: testKey))

        XCTAssertEqual(capturedData, expectedData, "Expected load to return the same data from reader.")
        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Expected errorHandler not to be notified on success.")
        XCTAssertEqual(readerSpy.receivedMessages, [.load(key: testKey)], "Expected load to be called on reader with the correct key.")
    }

    func test_save_whenEncryptorFails_notifiesHandlerAndRethrowsError() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let testData = Data("any data".utf8)
        let testKey = "anyKey"
        let expectedError = KeychainError.encryptionFailed

        encryptorSpy.completeEncrypt(with: expectedError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.save(data: testData, forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Expected save to rethrow the same error from encryptor.")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: testKey, operation: "save")], "Expected errorHandler to be notified with correct error, key, and operation.")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: testData)], "Expected encrypt to be called on encryptor with the correct data.")
    }

    func test_save_whenWriterFails_notifiesHandlerAndRethrowsError() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("plain data".utf8)
        let encryptedData = Data("encrypted data".utf8) // Simulating encryption
        let testKey = "anyKey"
        let expectedError = KeychainError.duplicateItem // Example writer error

        encryptorSpy.completeEncrypt(with: encryptedData) // Encryptor succeeds
        writerSpy.completeSave(with: expectedError) // Writer fails

        var capturedError: Error?
        XCTAssertThrowsError(try sut.save(data: plainData, forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Expected save to rethrow the same error from writer.")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: testKey, operation: "save")], "Expected errorHandler to be notified with correct error, key, and operation.")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: plainData)], "Expected encrypt to be called on encryptor.")
        XCTAssertEqual(writerSpy.receivedMessages, [.save(data: encryptedData, key: testKey)], "Expected save to be called on writer with encrypted data.")
    }

    func test_save_whenEncryptionAndWriteSucceed_doesNotNotifyHandler() {
        let (sut, _, writerSpy, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("plain data".utf8)
        let encryptedData = Data("encrypted data".utf8)
        let testKey = "anyKey"

        encryptorSpy.completeEncrypt(with: encryptedData)
        writerSpy.completeSaveSuccessfully() // Ensure writer is set up to succeed

        XCTAssertNoThrow(try sut.save(data: plainData, forKey: testKey), "Expected save to not throw an error.")

        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Expected errorHandler not to be notified on success.")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: plainData)], "Expected encrypt to be called on encryptor with plain data.")
        XCTAssertEqual(writerSpy.receivedMessages, [.save(data: encryptedData, key: testKey)], "Expected save to be called on writer with encrypted data and key.")
    }

    func test_delete_whenWriterThrowsError_notifiesHandlerAndRethrowsError() {
        let (sut, _, writerSpy, _, errorHandlerSpy) = makeSUT()
        let testKey = "anyKey"
        let expectedError = KeychainError.itemNotFound // Or any other relevant KeychainError for delete

        writerSpy.completeDelete(with: expectedError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.delete(forKey: testKey)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Expected delete to rethrow the same error from writer.")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: testKey, operation: "delete")], "Expected errorHandler to be notified with correct error, key, and operation.")
        XCTAssertEqual(writerSpy.receivedMessages, [.delete(key: testKey)], "Expected delete to be called on writer with the correct key.")
    }

    func test_delete_whenWriterSucceeds_doesNotNotifyHandler() {
        let (sut, _, writerSpy, _, errorHandlerSpy) = makeSUT()
        let testKey = "anyKey"

        writerSpy.completeDeleteSuccessfully()

        XCTAssertNoThrow(try sut.delete(forKey: testKey), "Expected delete to not throw an error.")

        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Expected errorHandler not to be notified on success.")
        XCTAssertEqual(writerSpy.receivedMessages, [.delete(key: testKey)], "Expected delete to be called on writer with the correct key.")
    }

    func test_encrypt_whenEncryptorThrowsError_notifiesHandlerAndRethrowsError() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let testData = Data("plain data".utf8)
        let expectedError = KeychainError.encryptionFailed

        encryptorSpy.completeEncrypt(with: expectedError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.encrypt(testData)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Expected encrypt to rethrow error from encryptor.")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: nil, operation: "encrypt")], "Expected errorHandler notification for encrypt failure.")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: testData)], "Expected encrypt to be called on encryptor.")
    }

    func test_encrypt_whenEncryptorSucceeds_returnsDataAndDoesNotNotifyHandler() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let plainData = Data("plain data".utf8)
        let expectedEncryptedData = Data("encrypted data".utf8)

        encryptorSpy.completeEncrypt(with: expectedEncryptedData)

        var capturedData: Data?
        XCTAssertNoThrow(capturedData = try sut.encrypt(plainData))

        XCTAssertEqual(capturedData, expectedEncryptedData, "Expected encrypt to return data from encryptor.")
        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Expected no errorHandler notification on encrypt success.")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.encrypt(data: plainData)], "Expected encrypt to be called on encryptor.")
    }

    func test_decrypt_whenEncryptorThrowsError_notifiesHandlerAndRethrowsError() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let encryptedData = Data("encrypted data".utf8)
        let expectedError = KeychainError.decryptionFailed

        encryptorSpy.completeDecrypt(with: expectedError)

        var capturedError: Error?
        XCTAssertThrowsError(try sut.decrypt(encryptedData)) { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError as? KeychainError, expectedError, "Expected decrypt to rethrow error from encryptor.")
        XCTAssertEqual(errorHandlerSpy.receivedMessages, [.handled(error: expectedError, key: nil, operation: "decrypt")], "Expected errorHandler notification for decrypt failure.")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.decrypt(data: encryptedData)], "Expected decrypt to be called on encryptor.")
    }

    func test_decrypt_whenEncryptorSucceeds_returnsDataAndDoesNotNotifyHandler() {
        let (sut, _, _, encryptorSpy, errorHandlerSpy) = makeSUT()
        let encryptedData = Data("encrypted data".utf8)
        let expectedPlainData = Data("plain data".utf8)

        encryptorSpy.completeDecrypt(with: expectedPlainData)

        var capturedData: Data?
        XCTAssertNoThrow(capturedData = try sut.decrypt(encryptedData))

        XCTAssertEqual(capturedData, expectedPlainData, "Expected decrypt to return data from encryptor.")
        XCTAssertTrue(errorHandlerSpy.receivedMessages.isEmpty, "Expected no errorHandler notification on decrypt success.")
        XCTAssertEqual(encryptorSpy.receivedMessages, [.decrypt(data: encryptedData)], "Expected decrypt to be called on encryptor.")
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
        let readerSpy = reader as! KeychainReaderSpy
        let writerSpy = writer as! KeychainWriterSpy
        let encryptorSpy = encryptor as! KeychainEncryptorSpy
        let errorHandlerSpy = errorHandler as! KeychainErrorHandlerSpy

        let sut = KeychainManager(
            reader: readerSpy,
            writer: writerSpy,
            encryptor: encryptorSpy,
            errorHandler: errorHandlerSpy
        )

        // trackForMemoryLeaks(sut, file: file, line: line)
        // trackForMemoryLeaks(readerSpy, file: file, line: line)
        // trackForMemoryLeaks(writerSpy, file: file, line: line)
        // trackForMemoryLeaks(encryptorSpy, file: file, line: line)
        // trackForMemoryLeaks(errorHandlerSpy, file: file, line: line)

        return (sut, readerSpy, writerSpy, encryptorSpy, errorHandlerSpy)
    }
}
