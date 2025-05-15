
import EssentialFeed
import XCTest

final class InMemoryFailedLoginAttemptsStoreTests: XCTestCase {
    func test_getAttempts_deliversZeroByDefault() {
        let sut = makeSUT()
        XCTAssertEqual(sut.getAttempts(for: "user"), 0)
    }

    func test_incrementAttempts_increasesCount() async {
        let sut = makeSUT()
        await sut.incrementAttempts(for: "user")
        XCTAssertEqual(sut.getAttempts(for: "user"), 1)
    }

    func test_resetAttempts_setsCountToZero() async {
        let sut = makeSUT()
        await sut.incrementAttempts(for: "user")
        await sut.resetAttempts(for: "user")
        XCTAssertEqual(sut.getAttempts(for: "user"), 0)
    }

    func test_lastAttemptTime_returnsNilByDefault_andUpdatesOnIncrement() async {
        let sut = makeSUT()
        XCTAssertNil(sut.lastAttemptTime(for: "user"))
        await sut.incrementAttempts(for: "user")
        XCTAssertNotNil(sut.lastAttemptTime(for: "user"))
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> InMemoryFailedLoginAttemptsStore {
        let sut = InMemoryFailedLoginAttemptsStore()
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
}
