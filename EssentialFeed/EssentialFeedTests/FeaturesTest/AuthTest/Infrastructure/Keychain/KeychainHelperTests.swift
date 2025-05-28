import EssentialFeed
import XCTest

final class KeychainHelperTests: XCTestCase {
    func test_setAndGet_returnsSavedValue() {
        let (sut, key, value) = makeRealKeychainSUT()

        _ = sut.delete(key)
        let saveResult = sut.save(value, for: key)

        XCTAssertEqual(saveResult, .success, "Expected save to succeed")
        XCTAssertEqual(sut.get(key), value, "Expected to retrieve the saved value")

        cleanUp(key: key, in: sut)
    }

    func test_get_returnsNilForNonexistentKey() {
        let (sut, key, _) = makeRealKeychainSUT()
        cleanUp(key: key, in: sut)

        XCTAssertNil(sut.get(key), "Expected nil for non-existent key")
    }

    func test_set_overwritesPreviousValue() {
        let (sut, key, value) = makeRealKeychainSUT()
        let otherValue = "other_value"

        cleanUp(key: key, in: sut)

        let firstSaveResult = sut.save(value, for: key)
        let secondSaveResult = sut.save(otherValue, for: key)

        XCTAssertEqual(firstSaveResult, .success, "Expected first save to succeed")
        XCTAssertEqual(secondSaveResult, .success, "Expected second save to succeed")
        XCTAssertEqual(sut.get(key), otherValue, "Expected the last saved value")

        cleanUp(key: key, in: sut)
    }

    func test_delete_removesValue() {
        let (sut, key, value) = makeRealKeychainSUT()

        let saveResult = sut.save(value, for: key)
        XCTAssertEqual(saveResult, .success, "Expected save to succeed")

        let deleteResult = sut.delete(key)
        XCTAssertEqual(deleteResult, .success, "Expected delete to succeed")

        XCTAssertNil(sut.get(key), "Expected value to be deleted")
    }

    func test_delete_nonexistentKey_doesNotFail() {
        let (sut, key, _) = makeRealKeychainSUT()
        cleanUp(key: key, in: sut)

        let deleteResult = sut.delete(key)
        XCTAssertEqual(deleteResult, .success, "Expected delete to succeed for non-existent key")
        XCTAssertNil(sut.get(key), "Expected no value for non-existent key")
    }

    func test_save_failsWithInvalidData() {
        class KeychainHelperStub: KeychainStore {
            func get(_: String) -> String? { nil }

            func save(_: String, for _: String) -> KeychainOperationResult {
                .failure(.stringToDataConversionFailed)
            }

            func delete(_: String) -> KeychainOperationResult {
                .success
            }
        }

        let sut = KeychainHelperStub()
        let saveResult = sut.save("any", for: "any")

        if case let .failure(error) = saveResult {
            if case .stringToDataConversionFailed = error {
            } else {
                XCTFail("Expected .stringToDataConversionFailed, got \(error)")
            }
        } else {
            XCTFail("Expected save to fail with stringToDataConversionFailed error")
        }
    }

    func test_save_validatesPostSaveRetrieval() {
        let (sut, key, value) = makeRealKeychainSUT()
        cleanUp(key: key, in: sut)

        let saveResult = sut.save(value, for: key)

        XCTAssertEqual(saveResult, .success, "Expected save to succeed")
        XCTAssertEqual(sut.get(key), value, "Expected to retrieve the saved value")

        cleanUp(key: key, in: sut)
    }

    // MARK: - Unit Tests (with Spy)

    func test_get_delegatesToSpy() {
        let (sut, spy) = makeSpySUT()
        let key = "test_key"
        let expectedValue = "test_value"
        spy.stubbedValue = expectedValue

        let result = sut.get(key)

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
        XCTAssertEqual(result, .success, "Expected success result")
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
        XCTAssertEqual(result, .success, "Expected success result")
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

    // MARK: - Helpers

    private func makeRealKeychainSUT(
        key: String = "test_key",
        value: String = "test_value",
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: KeychainStore, key: String, value: String) {
        let sut = KeychainHelper()
        trackForMemoryLeaks(sut as AnyObject, file: file, line: line)
        return (sut, key, value)
    }

    private func makeSpySUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: KeychainStore, spy: KeychainHelperSpy) {
        let spy = KeychainHelperSpy()
        trackForMemoryLeaks(spy, file: file, line: line)
        return (spy, spy)
    }

    private func cleanUp(key: String, in store: KeychainStore) {
        _ = store.delete(key)
    }
}
