import EssentialApp
import EssentialFeed
import XCTest

final class InMemoryOfflineRegistrationStoreStubTests: XCTestCase {
    func test_save_storesDataCorrectly() async throws {
        let sut = makeSUT()
        let userData1 = UserRegistrationData(name: "John", email: "john@test.com", password: "password123")
        let userData2 = UserRegistrationData(name: "Jane", email: "jane@test.com", password: "password456")

        try await sut.save(userData1)
        try await sut.save(userData2)

        let storedCount = await sut.storedDataCount
        XCTAssertEqual(storedCount, 2, "Should store both registration data entries")
    }

    func test_save_doesNotThrow() async {
        let sut = makeSUT()
        let userData = UserRegistrationData(name: "John", email: "john@test.com", password: "password123")

        do {
            try await sut.save(userData)
        } catch {
            XCTFail("Save should not throw error, but got: \(error)")
        }
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> InMemoryOfflineRegistrationStoreStub {
        let sut = InMemoryOfflineRegistrationStoreStub()
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
}

private actor InMemoryOfflineRegistrationStoreStub: OfflineRegistrationStore {
    private var storedData: [UserRegistrationData] = []

    var storedDataCount: Int {
        storedData.count
    }

    func save(_ data: UserRegistrationData) async throws {
        storedData.append(data)
    }
}
