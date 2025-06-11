import EssentialFeed
import XCTest

final class ExponentialBackoffPolicyTests: XCTestCase {
    func test_backoffDuration_whenNoFailedAttempts_shouldBeZero() {
        let sut = makeSUT()
        XCTAssertEqual(sut.backoffDuration(for: 0), 0)
    }

    func test_backoffDuration_whenOneFailedAttempt_shouldBeBaseDelay() {
        let sut = makeSUT()
        XCTAssertEqual(sut.backoffDuration(for: 1), 2)
    }

    func test_backoffDuration_whenMultipleAttempts_shouldGrowExponentially() {
        let sut = makeSUT()
        XCTAssertEqual(sut.backoffDuration(for: 2), 4)
        XCTAssertEqual(sut.backoffDuration(for: 3), 8)
        XCTAssertEqual(sut.backoffDuration(for: 4), 16)
    }

    func test_backoffDuration_shouldNotExceedMaxDelay() {
        let sut = makeSUT(baseDelay: 2, factor: 2, maxDelay: 10)
        XCTAssertEqual(sut.backoffDuration(for: 4), 10)
        XCTAssertEqual(sut.backoffDuration(for: 5), 10)
        XCTAssertEqual(sut.backoffDuration(for: 6), 10)
        XCTAssertEqual(sut.backoffDuration(for: 10), 10)
    }

    // MARK: - Helpers

    private func makeSUT(
        baseDelay: TimeInterval = 2,
        factor: Double = 2,
        maxDelay: TimeInterval = 60,
        file _: StaticString = #filePath,
        line _: UInt = #line
    ) -> ExponentialBackoffPolicy {
        ExponentialBackoffPolicy(baseDelay: baseDelay, factor: factor, maxDelay: maxDelay)
    }
}
