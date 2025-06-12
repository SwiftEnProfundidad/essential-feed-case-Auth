import EssentialFeed
import XCTest

final class KeychainManagerIntegrationTests: XCTestCase {
    func test_save_load_and_delete_flow() {
        let sut = makeSUT()
        let key = "integration-key-\(UUID().uuidString)"
        let value = "real-value-\(UUID().uuidString)".data(using: .utf8)!
        defer { _ = sut.delete(forKey: key) }

        let saveResult = sut.save(data: value, forKey: key)
        XCTAssertEqual(saveResult, .success, "Should save data into system keychain")

        let loaded = sut.load(forKey: key)
        XCTAssertEqual(loaded, value, "Should load the same data that was saved")

        let deleteResult = sut.delete(forKey: key)
        XCTAssertTrue(deleteResult, "Should delete value from system keychain")

        let shouldBeNil = sut.load(forKey: key)
        XCTAssertNil(shouldBeNil, "Loaded value should be nil after deletion")
    }

    func test_delete_nonexistent_key_is_idempotent() {
        let sut = makeSUT()
        let key = "nonexistent-\(UUID().uuidString)"
        let result = sut.delete(forKey: key)
        XCTAssertTrue(result, "Deleting a non-existent key should be idempotent and return true")
    }

    func test_overwrite_replaces_existing_value() {
        let sut = makeSUT()
        let key = "overwrite-key-\(UUID().uuidString)"
        let initial = "init-\(UUID().uuidString)".data(using: .utf8)!
        let replacement = "replacement-\(UUID().uuidString)".data(using: .utf8)!
        defer { _ = sut.delete(forKey: key) }

        XCTAssertEqual(sut.save(data: initial, forKey: key), .success)
        XCTAssertEqual(sut.save(data: replacement, forKey: key), .success)
        XCTAssertEqual(sut.load(forKey: key), replacement, "Should load the replacement value after overwrite")
    }

    func test_save_empty_data_returns_failure() {
        let sut = makeSUT()
        let key = "emptydata-\(UUID().uuidString)"
        let result = sut.save(data: Data(), forKey: key)
        XCTAssertEqual(result, .failure, "Saving empty Data should fail and not write to keychain")
    }

    func test_save_empty_key_returns_failure() {
        let sut = makeSUT()
        let value = "some-value-\(UUID().uuidString)".data(using: .utf8)!
        let result = sut.save(data: value, forKey: "")
        XCTAssertEqual(result, .failure, "Saving with empty key should fail and not write to keychain")
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> SystemKeychain {
        let sut = SystemKeychain()
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
}
