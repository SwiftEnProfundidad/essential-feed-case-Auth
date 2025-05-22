import EssentialApp
import EssentialFeed
import XCTest

final class KeychainHelperTests: XCTestCase {
    // MARK: - Tests

    func test_setAndGet_returnsSavedValue() {
        let (sut, key, value) = makeSUT()

        setValue(value, for: key, in: sut)

        XCTAssertEqual(sut.get(key), value)

        cleanup(key: key, in: sut)
    }

    func test_get_returnsNilForNonexistentKey() {
        let (sut, key, _) = makeSUT()

        cleanup(key: key, in: sut)

        XCTAssertNil(sut.get(key))
    }

    func test_set_overwritesPreviousValue() {
        let (sut, key, value) = makeSUT()
        let otherValue = "other_value"

        setValue(value, for: key, in: sut)
        setValue(otherValue, for: key, in: sut)

        XCTAssertEqual(sut.get(key), otherValue)

        cleanup(key: key, in: sut)
    }

    func test_delete_removesValue() {
        let (sut, key, value) = makeSUT()

        setValue(value, for: key, in: sut)
        sut.delete(key)

        XCTAssertNil(sut.get(key))
    }

    func test_delete_nonexistentKey_doesNotCrash() {
        let (sut, key, _) = makeSUT()

        sut.delete(key)

        XCTAssertNil(sut.get(key))
    }

    // MARK: - Helpers

    private func makeSUT(
        key: String = "test_key",
        value: String = "test_value",
        file: StaticString = #file,
        line: UInt = #line
    ) -> (sut: KeychainStore, key: String, value: String) {
        let sut = InMemoryKeychainStore()
        trackForMemoryLeaks(sut as AnyObject, file: file, line: line)
        return (sut, key, value)
    }

    private func setValue(_ value: String, for key: String, in store: KeychainStore) {
        _ = store.save(value, for: key)
    }

    private func cleanup(key: String, in store: KeychainStore) {
        store.delete(key)
    }
}
