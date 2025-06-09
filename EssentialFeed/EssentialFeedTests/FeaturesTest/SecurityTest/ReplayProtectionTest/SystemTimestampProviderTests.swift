import EssentialFeed
import XCTest

final class SystemTimestampProviderTests: XCTestCase {
    func test_currentTimestamp_returnsValidTimestamp() {
        let sut = makeSUT()
        let beforeCall = Date().timeIntervalSince1970 * 1000

        let timestamp = sut.currentTimestamp()

        let afterCall = Date().timeIntervalSince1970 * 1000
        XCTAssertGreaterThanOrEqual(Double(timestamp), beforeCall, "Timestamp should be after or equal to before call time")
        XCTAssertLessThanOrEqual(Double(timestamp), afterCall, "Timestamp should be before or equal to after call time")
    }

    func test_currentTimestamp_isInMilliseconds() {
        let sut = makeSUT()

        let timestamp = sut.currentTimestamp()

        let currentYear = Calendar.current.component(.year, from: Date())
        let timestampAsDate = Date(timeIntervalSince1970: Double(timestamp) / 1000)
        let timestampYear = Calendar.current.component(.year, from: timestampAsDate)

        XCTAssertEqual(timestampYear, currentYear, "Timestamp should represent current time in milliseconds")
    }

    func test_currentTimestamp_progressesOverTime() async {
        let sut = makeSUT()

        let timestamp1 = sut.currentTimestamp()
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        let timestamp2 = sut.currentTimestamp()

        XCTAssertGreaterThan(timestamp2, timestamp1, "Later timestamp should be greater than earlier timestamp")
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> SystemTimestampProvider {
        let sut = SystemTimestampProvider()
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
}
