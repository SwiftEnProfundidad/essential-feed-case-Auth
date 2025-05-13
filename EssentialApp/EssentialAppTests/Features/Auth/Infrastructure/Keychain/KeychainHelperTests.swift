
import EssentialApp
import XCTest

final class KeychainHelperTests: XCTestCase {
    private let key = "test_key"
    private let value = "test_value"
    private let otherValue = "other_value"

    func test_setAndGet_returnsSavedValue() {
        let sut = makeSUT()
        sut.delete(key)
        sut.set(value, for: key)
        XCTAssertEqual(sut.get(key), value)
        sut.delete(key)
    }

    func test_get_returnsNilForNonexistentKey() {
        let sut = makeSUT()
        sut.delete(key)
        XCTAssertNil(sut.get(key))
    }

    func test_set_overwritesPreviousValue() {
        let sut = makeSUT()
        sut.delete(key)
        sut.set(value, for: key)
        sut.set(otherValue, for: key)
        XCTAssertEqual(sut.get(key), otherValue)
        sut.delete(key)
    }

    func test_delete_removesValue() {
        let sut = makeSUT()
        sut.set(value, for: key)
        sut.delete(key)
        XCTAssertNil(sut.get(key))
    }

    func test_delete_nonexistentKey_doesNotCrash() {
        let sut = makeSUT()
        sut.delete(key)
        XCTAssertNil(sut.get(key))
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #file, line: UInt = #line) -> KeychainHelper {
        let sut = KeychainHelper()
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
}
