import EssentialFeed
import XCTest

final class KeychainHelperTests: XCTestCase {
    func test_setAndGet_returnsSavedValue() {
        let (sut, key, value) = makeSUT()

        sut.delete(key)
        sut.set(value, for: key)

        XCTAssertEqual(sut.get(key), value)
        cleanUp(key: key, in: sut)
    }

    func test_get_returnsNilForNonexistentKey() {
        let (sut, key, _) = makeSUT()
        cleanUp(key: key, in: sut)

        XCTAssertNil(sut.get(key))
    }

    func test_set_overwritesPreviousValue() {
        let (sut, key, value) = makeSUT()
        let otherValue = "other_value"

        cleanUp(key: key, in: sut)
        sut.set(value, for: key)
        sut.set(otherValue, for: key)

        XCTAssertEqual(sut.get(key), otherValue)
        cleanUp(key: key, in: sut)
    }

    func test_delete_removesValue() {
        let (sut, key, value) = makeSUT()

        sut.set(value, for: key)
        sut.delete(key)

        XCTAssertNil(sut.get(key))
    }

    func test_delete_nonexistentKey_doesNotCrash() {
        let (sut, key, _) = makeSUT()

        cleanUp(key: key, in: sut)

        sut.delete(key)
        XCTAssertNil(sut.get(key))
    }

    // MARK: - Helpers

    private func makeSUT(
        key: String = "test_key",
        value: String = "test_value",
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: KeychainStore, key: String, value: String) {
        let sut = InMemoryKeychainStore()
        trackForMemoryLeaks(sut as AnyObject, file: file, line: line)
        return (sut, key, value)
    }

    private func cleanUp(key: String, in store: KeychainStore) {
        store.delete(key)
    }
}
