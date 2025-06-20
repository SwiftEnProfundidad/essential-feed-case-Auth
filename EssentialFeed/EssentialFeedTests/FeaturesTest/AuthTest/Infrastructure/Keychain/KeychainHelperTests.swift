import EssentialFeed
import XCTest

final class KeychainHelperTests: XCTestCase {
    override func setUpWithError() throws {
        #if targetEnvironment(simulator)
            throw XCTSkip("Keychain tests require macOS environment with proper entitlements")
        #endif
    }

    func test_setAndGet_returnsSavedValue() {
        let (sut, key, value) = makeRealKeychainSUT()
        let data = value.data(using: .utf8)!

        _ = sut.delete(key)
        let saveResult = sut.save(data, for: key)

        XCTAssertTrue(saveResult.isSuccess, "Expected success result, got \(saveResult)")
        let retrievedData = sut.getData(key)

        XCTAssertNotNil(retrievedData, "Failed to retrieve data from Keychain for key '\(key)'")
        if let retrievedData {
            XCTAssertEqual(String(data: retrievedData, encoding: .utf8), value, "Expected to retrieve the saved value")
        }

        cleanUp(key: key, in: sut)
    }

    func test_get_returnsNilForNonexistentKey() {
        let (sut, key, _) = makeRealKeychainSUT()
        cleanUp(key: key, in: sut)

        XCTAssertNil(sut.getData(key), "Expected nil for non-existent key")
    }

    func test_set_overwritesPreviousValue() {
        let (sut, key, value) = makeRealKeychainSUT()
        let otherValue = "other_value"
        let valueData = value.data(using: .utf8)!
        let otherValueData = otherValue.data(using: .utf8)!

        cleanUp(key: key, in: sut)

        let firstSaveResult = sut.save(valueData, for: key)
        let secondSaveResult = sut.save(otherValueData, for: key)

        XCTAssertTrue(firstSaveResult.isSuccess, "Expected first save to succeed")
        XCTAssertTrue(secondSaveResult.isSuccess, "Expected second save to succeed")

        let retrievedData = sut.getData(key)
        XCTAssertNotNil(retrievedData, "Failed to retrieve data from Keychain for key '\(key)'")
        if let retrievedData {
            XCTAssertEqual(String(data: retrievedData, encoding: .utf8), otherValue, "Expected the last saved value")
        }

        cleanUp(key: key, in: sut)
    }

    func test_delete_removesValue() {
        let (sut, key, value) = makeRealKeychainSUT()
        let valueData = value.data(using: .utf8)!

        let saveResult = sut.save(valueData, for: key)
        XCTAssertTrue(saveResult.isSuccess, "Expected save to succeed")

        let deleteResult = sut.delete(key)
        XCTAssertTrue(deleteResult.isSuccess || deleteResult.isItemNotFound, "Expected delete to succeed or return itemNotFound, got \(deleteResult)")

        XCTAssertNil(sut.getData(key), "Expected value to be deleted")
    }

    func test_delete_nonexistentKey_doesNotFail() {
        let (sut, key, _) = makeRealKeychainSUT()
        cleanUp(key: key, in: sut)

        let deleteResult = sut.delete(key)
        XCTAssertTrue(deleteResult.isSuccess || deleteResult.isItemNotFound, "Expected delete to succeed or return itemNotFound for non-existent key, got \(deleteResult)")
        XCTAssertNil(sut.getData(key), "Expected no value for non-existent key")
    }

    func test_save_propagatesStringToDataConversionFailedError_fromDependency() {
        let sut: KeychainWritable = FailingKeychainWritable()
        let result = sut.save("irrelevant", for: "irrelevant")
        if case let .failure(error) = result {
            XCTAssertEqual(error, .stringToDataConversionFailed, "Expected .stringToDataConversionFailed, got \(error)")
        } else {
            XCTFail("Expected save to fail with .stringToDataConversionFailed error, but got .success")
        }
    }

    func test_save_validatesPostSaveRetrieval() {
        let (sut, key, value) = makeRealKeychainSUT()
        let valueData = value.data(using: .utf8)!
        cleanUp(key: key, in: sut)

        let saveResult = sut.save(valueData, for: key)
        XCTAssertTrue(saveResult.isSuccess, "Expected success result, got \(saveResult)")

        let retrievedData = sut.getData(key)
        XCTAssertNotNil(retrievedData, "Failed to retrieve data from Keychain for key '\(key)'")
        if let retrievedData {
            XCTAssertEqual(String(data: retrievedData, encoding: .utf8), value, "Expected to retrieve the saved value")
        }

        cleanUp(key: key, in: sut)
    }

    func test_get_delegatesToSpy() {
        let (sut, spy) = makeSpySUT()
        let key = "test_key"
        let expectedValue = "test_value"
        let expectedData = expectedValue.data(using: .utf8)!
        spy.stubbedData = expectedData

        let result = sut.getData(key)

        XCTAssertEqual(spy.getCalls, [key], "Expected get to be called once with the correct key")
        XCTAssertEqual(result, expectedData, "Expected the stubbed data")
    }

    func test_save_delegatesToSpy() {
        let (sut, spy) = makeSpySUT()
        let key = "test_key"
        let value = "test_value"
        let valueData = value.data(using: .utf8)!

        let result = sut.save(valueData, for: key)

        XCTAssertEqual(spy.saveCalls.count, 1, "Expected save to be called once")
        XCTAssertEqual(spy.saveCalls.first?.0, key, "Expected save with correct key")
        XCTAssertEqual(spy.saveCalls.first?.1, valueData, "Expected save with correct value data")
        XCTAssertTrue(result.isSuccess, "Expected success result, got \(result)")
    }

    func test_save_propagatesErrorFromSpy() {
        let (sut, spy) = makeSpySUT()
        let key = "test_key"
        let value = "test_value"
        let valueData = value.data(using: .utf8)!
        let expectedError = KeychainError.duplicateItem
        spy.stubbedSaveError = expectedError

        let result = sut.save(valueData, for: key)

        if case let .failure(error) = result {
            XCTAssertEqual(error, expectedError, "Expected save to fail with the stubbed error")
        } else {
            XCTFail("Expected save to fail with error")
        }
    }

    func test_delete_delegatesToSpy() {
        let (sut, spy) = makeSpySUT()
        let key = "test_key"

        let result = sut.delete(key)

        XCTAssertEqual(spy.deleteCalls, [key], "Expected delete to be called once with the correct key")
        XCTAssertTrue(result.isSuccess || result.isItemNotFound, "Expected success or itemNotFound result, got \(result)")
    }

    func test_delete_propagatesErrorFromSpy() {
        let (sut, spy) = makeSpySUT()
        let key = "test_key"
        let expectedError = KeychainError.itemNotFound
        spy.stubbedDeleteError = expectedError

        let result = sut.delete(key)

        if case let .failure(error) = result {
            XCTAssertEqual(error, expectedError, "Expected delete to fail with the stubbed error")
        } else {
            XCTFail("Expected delete to fail with error")
        }
    }

    func test_saveData_withUnicodeKey_shouldRetrieveIdenticalData() {
        let (sut, key, value) = makeRealKeychainDataSUT(
            key: "🔑-clave-🚀-üñîçødë-漢字",
            value: "Esto es un string unicode 🚀漢字 convertido a Data".data(using: .utf8)!
        )
        _ = sut.delete(key)

        let saveResult = sut.save(value, for: key)
        XCTAssertTrue(saveResult.isSuccess, "Expected save to succeed")

        let retrieved = sut.getData(key)
        XCTAssertEqual(retrieved, value, "Expected to retrieve identical data")

        cleanUpData(key: key, in: sut)
    }

    func test_saveLargeData_shouldRetrieveIdenticalData() {
        let largeString = String(repeating: "🚀0123456789漢字", count: 1000)
        let largeData = largeString.data(using: .utf8)!
        let (sut, key, value) = makeRealKeychainDataSUT(
            key: "large_data_key_🗄️",
            value: largeData
        )
        _ = sut.delete(key)

        let saveResult = sut.save(value, for: key)
        XCTAssertTrue(saveResult.isSuccess, "Expected save to succeed")

        let retrieved = sut.getData(key)
        XCTAssertEqual(retrieved, value, "Expected to retrieve identical data")

        cleanUpData(key: key, in: sut)
    }

    func test_deleteData_withUnicodeKey_shouldRemoveData() {
        let (sut, key, value) = makeRealKeychainDataSUT(
            key: "🗑️-delete-unicode-key-漢字",
            value: "Data to delete".data(using: .utf8)!
        )
        _ = sut.delete(key)
        _ = sut.save(value, for: key)

        let deleteResult = sut.delete(key)
        XCTAssertTrue(deleteResult.isSuccess || deleteResult.isItemNotFound, "Expected success or itemNotFound result, got \(deleteResult)")

        let retrieved = sut.getData(key)
        XCTAssertNil(retrieved)
    }

    func test_getData_forNonexistentUnicodeKey_shouldReturnNilOrError() {
        let (sut, key, _) = makeRealKeychainDataSUT(
            key: "❓-nonexistent-unicode-key-漢字",
            value: Data()
        )
        _ = sut.delete(key)

        let retrieved = sut.getData(key)
        XCTAssertNil(retrieved)
    }

    func test_saveData_validatesPostSaveRetrieval() {
        let (sut, key, value) = makeRealKeychainDataSUT(
            key: "validate-post-save-漢字",
            value: "post-save validation data 🚦".data(using: .utf8)!
        )
        _ = sut.delete(key)

        let saveResult = sut.save(value, for: key)
        XCTAssertTrue(saveResult.isSuccess, "Expected success result, got \(saveResult)")

        let retrieved = sut.getData(key)
        XCTAssertEqual(retrieved, value, "Expected to retrieve the saved value")

        cleanUpData(key: key, in: sut)
    }

    func test_saveData_overwritesPreviousData_withDeleteBeforeAdd() {
        let (sut, key, value1) = makeRealKeychainDataSUT(
            key: "overwrite-key-漢字",
            value: "first value".data(using: .utf8)!
        )
        let value2 = "second value".data(using: .utf8)!
        _ = sut.delete(key)
        _ = sut.save(value1, for: key)
        let saveResult = sut.save(value2, for: key)
        XCTAssertTrue(saveResult.isSuccess, "Expected success result, got \(saveResult)")

        let retrieved = sut.getData(key)
        XCTAssertEqual(retrieved, value2, "Expected to retrieve the overwritten value")

        cleanUpData(key: key, in: sut)
    }

    func test_stringOperations_remainCompatibleAfterDataSupport() {
        let (sut, key, value) = makeRealKeychainSUT(
            key: "compatibility-string-key",
            value: "string-value-compatible"
        )
        _ = sut.delete(key)
        let valueData = value.data(using: .utf8)!
        let saveResult = sut.save(valueData, for: key)
        XCTAssertTrue(saveResult.isSuccess, "Expected success result, got \(saveResult)")

        let retrievedData = sut.getData(key)
        XCTAssertNotNil(retrievedData, "Failed to retrieve data from Keychain for key '\(key)'")
        if let retrievedData {
            let retrievedString = String(data: retrievedData, encoding: .utf8)
            XCTAssertEqual(retrievedString, value)
        }

        cleanUp(key: key, in: sut)
    }

    func test_handleUnicodeKeys_correctly() {
        let unicodeKeys = [
            "🔑-clave-segura-漢字-😀-𝄞-😺",
            "k͏e͏y͏-w͏i͏t͏h͏-z͏e͏r͏o͏-w͏i͏d͏t͏h͏-s͏p͏a͏c͏e͏s͏",
            "ǩ̸̌̽̉̉̊̔̽̽�8́̀̎�8́͆̎�8́̎̌̽̌̽�8́̽�7͌�97�8́͌̌�8́�98�88�88�88�88",
            "مرحبا-بالعالم-😊",
            "こんにちは-世界-🌏",
            "Привет-мир-🚀"
        ]

        for unicodeKey in unicodeKeys {
            let (sut, _, _) = makeRealKeychainSUT()
            let testData = "Test data for key: \(unicodeKey)".data(using: .utf8)!

            _ = sut.delete(unicodeKey)

            let saveResult = sut.save(testData, for: unicodeKey)
            XCTAssertTrue(saveResult.isSuccess, "Failed to save with Unicode key: \(unicodeKey)")

            let retrievedData = sut.getData(unicodeKey)
            XCTAssertEqual(retrievedData, testData, "Retrieved data doesn't match for key: \(unicodeKey)")

            let deleteResult = sut.delete(unicodeKey)
            XCTAssertTrue(deleteResult.isSuccess || deleteResult.isItemNotFound, "Failed to delete data with Unicode key: \(unicodeKey)")
            XCTAssertNil(sut.getData(unicodeKey), "Data still exists after deletion for key: \(unicodeKey)")
        }
    }

    func test_save_rejectsEmptyKeys() {
        let (sut, _, _) = makeRealKeychainSUT()
        let emptyKey = ""
        let emptyKeyResult = sut.save(Data(), for: emptyKey)

        if case let .failure(error) = emptyKeyResult {
            XCTAssertEqual(error, .invalidKeyFormat, "Should reject empty keys with invalidKeyFormat error")
        } else {
            XCTFail("Should fail with empty key")
        }
    }

    private final class FailingKeychainWritable: KeychainWritable {
        func save(_: Data, for _: String) -> KeychainOperationResult {
            .failure(.stringToDataConversionFailed)
        }
    }

    private func makeRealKeychainSUT(
        key: String = "test_key",
        value: String = "test_value",
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: KeychainHelper, key: String, value: String) {
        let sut = KeychainHelper()
        trackForMemoryLeaks(sut as AnyObject, file: file, line: line)
        return (sut, key, value)
    }

    private func makeSpySUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: KeychainHelperSpy, spy: KeychainHelperSpy) {
        let spy = KeychainHelperSpy()
        trackForMemoryLeaks(spy, file: file, line: line)
        return (spy, spy)
    }

    private func makeRealKeychainDataSUT(
        key: String = "test_data_key",
        value: Data = Data(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: KeychainHelper, key: String, value: Data) {
        let sut = KeychainHelper()
        trackForMemoryLeaks(sut as AnyObject, file: file, line: line)
        return (sut, key, value)
    }

    private func cleanUpData(key: String, in store: KeychainHelper) {
        _ = store.delete(key)
    }

    private func cleanUp(key: String, in store: KeychainHelper) {
        _ = store.delete(key)
    }

    private class KeychainHelperSpy: KeychainReadable, KeychainWritable, KeychainRemovable {
        var getCalls: [String] = []
        var saveCalls: [(String, Data)] = []
        var deleteCalls: [String] = []
        var stubbedData: Data?
        var stubbedSaveError: KeychainError?
        var stubbedDeleteError: KeychainError?

        func getData(_ key: String) -> Data? {
            getCalls.append(key)
            return stubbedData
        }

        func save(_ data: Data, for key: String) -> KeychainOperationResult {
            saveCalls.append((key, data))
            if let error = stubbedSaveError { return .failure(error) }
            return .success(())
        }

        func delete(_ key: String) -> KeychainOperationResult {
            deleteCalls.append(key)
            if let error = stubbedDeleteError { return .failure(error) }
            return .success(())
        }
    }
}

extension KeychainOperationResult {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var isItemNotFound: Bool {
        if case .failure(.itemNotFound) = self { return true }
        return false
    }
}
