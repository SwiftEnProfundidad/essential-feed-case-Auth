import EssentialFeed
import XCTest

final class InMemoryOfflineRegistrationStoreTests: XCTestCase {
    func test_init_startsEmpty() {
        let sut = makeSUT()

        XCTAssertNotNil(sut, "Should initialize successfully")
    }

    func test_save_storesRegistrationDataInMemory() async throws {
        let sut = makeSUT()
        let registrationData = UserRegistrationData(name: "John", email: "john@example.com", password: "password")

        try await sut.save(registrationData)

        XCTAssertNoThrow("Should save registration data without throwing")
    }

    func test_save_multipleRegistrationData_doesNotThrow() async throws {
        let sut = makeSUT()
        let firstData = UserRegistrationData(name: "John", email: "john@example.com", password: "password")
        let secondData = UserRegistrationData(name: "Jane", email: "jane@example.com", password: "password123")

        try await sut.save(firstData)
        try await sut.save(secondData)

        XCTAssertNoThrow("Should save multiple registration data without throwing")
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> InMemoryOfflineRegistrationStore {
        let sut = InMemoryOfflineRegistrationStore()

        trackForMemoryLeaks(sut, file: file, line: line)

        return sut
    }
}
