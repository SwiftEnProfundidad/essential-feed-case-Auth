
import EssentialFeed
import XCTest

final class InMemoryFailedLoginAttemptsStoreTests: XCTestCase {
    func test_getAttempts_deliversZeroByDefault() {
        let sut = makeSUT()
        XCTAssertEqual(sut.getAttempts(for: "user"), 0)
    }

    func test_incrementAttempts_increasesCount() {
        let sut = makeSUT()
        sut.incrementAttempts(for: "user")
        let exp = expectation(description: "Wait for increment")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(sut.getAttempts(for: "user"), 1)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func test_resetAttempts_setsCountToZero() {
        let sut = makeSUT()
        sut.incrementAttempts(for: "user")
        let exp = expectation(description: "Wait for reset")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            sut.resetAttempts(for: "user")
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                XCTAssertEqual(sut.getAttempts(for: "user"), 0)
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 2.0)
    }

    func test_lastAttemptTime_returnsNilByDefault_andUpdatesOnIncrement() {
        let sut = makeSUT()
        XCTAssertNil(sut.lastAttemptTime(for: "user"))
        sut.incrementAttempts(for: "user")
        let exp = expectation(description: "Wait for lastAttemptTime")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotNil(sut.lastAttemptTime(for: "user"))
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> InMemoryFailedLoginAttemptsStore {
        let sut = InMemoryFailedLoginAttemptsStore()
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
}
