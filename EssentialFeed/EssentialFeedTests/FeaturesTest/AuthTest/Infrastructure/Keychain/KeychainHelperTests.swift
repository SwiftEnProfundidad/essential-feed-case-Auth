import EssentialFeed
import XCTest

final class KeychainHelperTests: XCTestCase {
    func test_setAndGet_returnsSavedValue() {
        let (sut, key, value) = makeRealKeychainSUT()

        _ = sut.delete(key)
        let saveResult = sut.save(value, for: key)

        XCTAssertEqual(saveResult, KeychainOperationResult.success, "Expected save to succeed")
        XCTAssertEqual(sut.getString(key), value, "Expected to retrieve the saved value")

        cleanUp(key: key, in: sut)
    }

    func test_get_returnsNilForNonexistentKey() {
        let (sut, key, _) = makeRealKeychainSUT()
        cleanUp(key: key, in: sut)

        XCTAssertNil(sut.getString(key), "Expected nil for non-existent key")
    }

    func test_set_overwritesPreviousValue() {
        let (sut, key, value) = makeRealKeychainSUT()
        let otherValue = "other_value"

        cleanUp(key: key, in: sut)

        let firstSaveResult = sut.save(value, for: key)
        let secondSaveResult = sut.save(otherValue, for: key)

        XCTAssertEqual(firstSaveResult, KeychainOperationResult.success, "Expected first save to succeed")
        XCTAssertEqual(secondSaveResult, KeychainOperationResult.success, "Expected second save to succeed")
        XCTAssertEqual(sut.getString(key), otherValue, "Expected the last saved value")

        cleanUp(key: key, in: sut)
    }

    func test_delete_removesValue() {
        let (sut, key, value) = makeRealKeychainSUT()

        let saveResult = sut.save(value, for: key)
        XCTAssertEqual(saveResult, KeychainOperationResult.success, "Expected save to succeed")

        let deleteResult = sut.delete(key)
        XCTAssertEqual(deleteResult, KeychainOperationResult.success, "Expected delete to succeed")

        XCTAssertNil(sut.getString(key), "Expected value to be deleted")
    }

    func test_delete_nonexistentKey_doesNotFail() {
        let (sut, key, _) = makeRealKeychainSUT()
        cleanUp(key: key, in: sut)

        let deleteResult = sut.delete(key)
        XCTAssertEqual(deleteResult, KeychainOperationResult.success, "Expected delete to succeed for non-existent key")
        XCTAssertNil(sut.getString(key), "Expected no value for non-existent key")
    }

    func test_save_propagatesStringToDataConversionFailedError_fromDependency() {
        let sut: KeychainWritable = FailingKeychainWritable()
        let result = sut.save("irrelevant", for: "irrelevant")
        switch result {
        case let .failure(error):
            XCTAssertEqual(error, .stringToDataConversionFailed, "Expected .stringToDataConversionFailed, got \(error)")
        case .success:
            XCTFail("Expected save to fail with .stringToDataConversionFailed error, but got .success")
        }
    }

    func test_save_validatesPostSaveRetrieval() {
        let (sut, key, value) = makeRealKeychainSUT()
        cleanUp(key: key, in: sut)

        let saveResult = sut.save(value, for: key)

        XCTAssertEqual(saveResult, KeychainOperationResult.success, "Expected save to succeed")
        XCTAssertEqual(sut.getString(key), value, "Expected to retrieve the saved value")

        cleanUp(key: key, in: sut)
    }

    func test_get_delegatesToSpy() {
        let (sut, spy) = makeSpySUT()
        let key = "test_key"
        let expectedValue = "test_value"
        spy.stubbedValue = expectedValue

        let result = sut.getString(key)

        XCTAssertEqual(spy.getCalls, [key], "Expected get to be called once with the correct key")
        XCTAssertEqual(result, expectedValue, "Expected the stubbed value")
    }

    func test_save_delegatesToSpy() {
        let (sut, spy) = makeSpySUT()
        let key = "test_key"
        let value = "test_value"

        let result = sut.save(value, for: key)

        XCTAssertEqual(spy.saveCalls.count, 1, "Expected save to be called once")
        XCTAssertEqual(spy.saveCalls.first?.0, key, "Expected save with correct key")
        XCTAssertEqual(spy.saveCalls.first?.1, value, "Expected save with correct value")
        XCTAssertEqual(result, KeychainOperationResult.success, "Expected success result")
    }

    func test_save_propagatesErrorFromSpy() {
        let (sut, spy) = makeSpySUT()
        let key = "test_key"
        let value = "test_value"
        let expectedError = KeychainError.duplicateItem
        spy.stubbedSaveError = expectedError

        let result = sut.save(value, for: key)

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
        XCTAssertEqual(result, KeychainOperationResult.success, "Expected success result")
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
        XCTAssertEqual(saveResult, KeychainOperationResult.success)

        let retrieved = sut.getData(key)
        XCTAssertEqual(retrieved, value)

        cleanUpData(key: key, in: sut)
    }

    func test_saveLargeData_shouldRetrieveIdenticalData() {
        let largeString = String(repeating: "🚀0123456789漢字", count: 10000)
        let largeData = largeString.data(using: .utf8)!
        let (sut, key, value) = makeRealKeychainDataSUT(
            key: "large_data_key_🗄️",
            value: largeData
        )
        _ = sut.delete(key)

        let saveResult = sut.save(value, for: key)
        XCTAssertEqual(saveResult, KeychainOperationResult.success)

        let retrieved = sut.getData(key)
        XCTAssertEqual(retrieved, value)

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
        XCTAssertEqual(deleteResult, KeychainOperationResult.success)

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
        XCTAssertEqual(saveResult, KeychainOperationResult.success)
        let retrieved = sut.getData(key)
        XCTAssertEqual(retrieved, value)
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
        XCTAssertEqual(saveResult, KeychainOperationResult.success)
        let retrieved = sut.getData(key)
        XCTAssertEqual(retrieved, value2)
    }

    func test_stringOperations_remainCompatibleAfterDataSupport() {
        let (sut, key, value) = makeRealKeychainSUT(
            key: "compatibility-string-key",
            value: "string-value-compatible"
        )
        _ = sut.delete(key)
        let saveResult = sut.save(value, for: key)
        XCTAssertEqual(saveResult, KeychainOperationResult.success)
        let retrieved = sut.getString(key)
        XCTAssertEqual(retrieved, value)
    }

    // MARK: - Doubles

    private final class FailingKeychainWritable: KeychainWritable {
        func save(_: Data, for _: String) -> KeychainOperationResult {
            .failure(.stringToDataConversionFailed)
        }
    }

    // MARK: - Helpers

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

    // MARK: - Test Doubles

    private class KeychainHelperSpy: KeychainReadable, KeychainWritable, KeychainRemovable {
        var getCalls: [String] = []
        var saveCalls: [(String, String)] = []
        var deleteCalls: [String] = []
        var stubbedValue: String?
        var stubbedSaveError: KeychainError?
        var stubbedDeleteError: KeychainError?

        func getData(_: String) -> Data? { nil }
        func getString(_ key: String) -> String? {
            getCalls.append(key)
            return stubbedValue
        }

        func save(_ string: String, for key: String) -> KeychainOperationResult {
            saveCalls.append((key, string))
            if let error = stubbedSaveError { return .failure(error) }
            return .success
        }

        func save(_: Data, for _: String) -> KeychainOperationResult { .success }
        func delete(_ key: String) -> KeychainOperationResult {
            deleteCalls.append(key)
            if let error = stubbedDeleteError { return .failure(error) }
            return .success
        }
    }
}
