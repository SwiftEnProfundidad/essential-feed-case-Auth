
import EssentialFeed
import XCTest

final class AnyFailedLoginAttemptStoreTests: XCTestCase {
    private final class StoreSpy: FailedLoginAttemptsStore {
        var getAttemptsCalled = false
        var incrementAttemptsCalled = false
        var resetAttemptsCalled = false
        var lastAttemptTimeCalled = false
        var attemptsResult = 0
        var lastAttemptResult: Date? = nil
        func getAttempts(for _: String) -> Int {
            getAttemptsCalled = true
            return attemptsResult
        }

        func incrementAttempts(for _: String) {
            incrementAttemptsCalled = true
        }

        func resetAttempts(for _: String) {
            resetAttemptsCalled = true
        }

        func lastAttemptTime(for _: String) -> Date? {
            lastAttemptTimeCalled = true
            return lastAttemptResult
        }
    }

    func test_getAttempts_delegatesToWrappedStore() {
        let (sut, spy) = makeSUT()
        spy.attemptsResult = 42
        XCTAssertEqual(sut.getAttempts(for: "user"), 42)
        XCTAssertTrue(spy.getAttemptsCalled)
    }

    func test_incrementAttempts_delegatesToWrappedStore() {
        let (sut, spy) = makeSUT()
        sut.incrementAttempts(for: "user")
        XCTAssertTrue(spy.incrementAttemptsCalled)
    }

    func test_resetAttempts_delegatesToWrappedStore() {
        let (sut, spy) = makeSUT()
        sut.resetAttempts(for: "user")
        XCTAssertTrue(spy.resetAttemptsCalled)
    }

    func test_lastAttemptTime_delegatesToWrappedStore() {
        let (sut, spy) = makeSUT()
        let expectedDate = Date()
        spy.lastAttemptResult = expectedDate
        XCTAssertEqual(sut.lastAttemptTime(for: "user"), expectedDate)
        XCTAssertTrue(spy.lastAttemptTimeCalled)
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: AnyFailedLoginAttemptStore, spy: StoreSpy) {
        let spy = StoreSpy()
        let sut = AnyFailedLoginAttemptStore(spy)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(spy, file: file, line: line)
        return (sut, spy)
    }
}
