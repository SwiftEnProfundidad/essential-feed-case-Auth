import EssentialFeed
import XCTest

final class PasswordRecoveryRateLimiterTests: XCTestCase {
    func test_isAllowed_returnsSuccess_whenNoRecentAttempts() {
        let (sut, _, _) = makeSUT()

        let result = sut.isAllowed(for: "test@example.com")

        if case .failure = result {
            XCTFail("Expected success when no recent attempts")
        }
    }

    func test_isAllowed_returnsSuccess_whenAttemptsAreBelowLimit() {
        let (sut, readerSpy, writerSpy) = makeSUT(maxAttempts: 3)
        let email = "test@example.com"

        recordAttempts(readerSpy: readerSpy, writerSpy: writerSpy, email: email, count: 2)

        let result = sut.isAllowed(for: email)

        if case .failure = result {
            XCTFail("Expected success when attempts are below limit")
        }
    }

    func test_isAllowed_returnsRateLimitError_whenAttemptsExceedLimit() {
        let (sut, readerSpy, writerSpy) = makeSUT(maxAttempts: 3)
        let email = "test@example.com"

        recordAttempts(readerSpy: readerSpy, writerSpy: writerSpy, email: email, count: 3)

        let result = sut.isAllowed(for: email)

        switch result {
        case .success:
            XCTFail("Expected rate limit error when attempts exceed limit")
        case let .failure(error):
            if case let .rateLimitExceeded(retryAfterSeconds) = error {
                XCTAssertGreaterThan(retryAfterSeconds, 0)
            } else {
                XCTFail("Expected rateLimitExceeded error, got \(error)")
            }
        }
    }

    func test_isAllowed_returnsSuccess_whenOldAttemptsAreOutsideTimeWindow() {
        let (sut, readerSpy, writerSpy) = makeSUT(maxAttempts: 3, timeWindowMinutes: 15)
        let email = "test@example.com"
        let oldTimestamp = Date().addingTimeInterval(-16 * 60)

        recordAttempts(readerSpy: readerSpy, writerSpy: writerSpy, email: email, count: 3, timestamp: oldTimestamp)

        let result = sut.isAllowed(for: email)

        if case .failure = result {
            XCTFail("Expected success when old attempts are outside time window")
        }
    }

    func test_recordAttempt_storesAttemptWithCorrectData() {
        let (sut, _, writerSpy) = makeSUT()
        let email = "test@example.com"
        let ipAddress = "192.168.1.1"

        sut.recordAttempt(for: email, ipAddress: ipAddress)

        XCTAssertEqual(writerSpy.recordedAttempts.count, 1)
        XCTAssertEqual(writerSpy.recordedAttempts.first?.email, email)
        XCTAssertEqual(writerSpy.recordedAttempts.first?.ipAddress, ipAddress)
        XCTAssertNotNil(writerSpy.recordedAttempts.first?.timestamp)
    }

    func test_recordAttempt_storesAttemptWithoutIPAddress() {
        let (sut, _, writerSpy) = makeSUT()
        let email = "test@example.com"

        sut.recordAttempt(for: email, ipAddress: nil)

        XCTAssertEqual(writerSpy.recordedAttempts.count, 1)
        XCTAssertEqual(writerSpy.recordedAttempts.first?.email, email)
        XCTAssertNil(writerSpy.recordedAttempts.first?.ipAddress)
    }

    func test_convenienteInit_withStore_worksCorrectly() {
        let store = InMemoryPasswordRecoveryRateLimitStore()
        let sut = DefaultPasswordRecoveryRateLimiter(store: store, maxAttempts: 5, timeWindowMinutes: 30)

        let result = sut.isAllowed(for: "test@example.com")

        if case .failure = result {
            XCTFail("Expected success with convenience init")
        }
    }

    // MARK: - Helpers

    private func makeSUT(
        maxAttempts: Int = 3,
        timeWindowMinutes: Int = 15,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: DefaultPasswordRecoveryRateLimiter, readerSpy: PasswordRecoveryAttemptReaderSpy, writerSpy: PasswordRecoveryAttemptWriterSpy) {
        let readerSpy = PasswordRecoveryAttemptReaderSpy()
        let writerSpy = PasswordRecoveryAttemptWriterSpy()
        let sut = DefaultPasswordRecoveryRateLimiter(
            attemptReader: readerSpy,
            attemptWriter: writerSpy,
            maxAttempts: maxAttempts,
            timeWindowMinutes: timeWindowMinutes
        )
        trackForMemoryLeaks(readerSpy, file: file, line: line)
        trackForMemoryLeaks(writerSpy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, readerSpy, writerSpy)
    }

    private func recordAttempts(
        readerSpy: PasswordRecoveryAttemptReaderSpy,
        writerSpy: PasswordRecoveryAttemptWriterSpy,
        email: String,
        count: Int,
        timestamp: Date = Date()
    ) {
        var attempts: [PasswordRecoveryAttempt] = []
        for _ in 0 ..< count {
            let attempt = PasswordRecoveryAttempt(email: email, timestamp: timestamp)
            attempts.append(attempt)
            writerSpy.recordedAttempts.append(attempt)
        }
        readerSpy.stubbedAttempts[email] = attempts
    }
}

// MARK: - Test Doubles

private final class PasswordRecoveryAttemptReaderSpy: PasswordRecoveryAttemptReader {
    var stubbedAttempts: [String: [PasswordRecoveryAttempt]] = [:]

    func getAttempts(for email: String) -> [PasswordRecoveryAttempt] {
        stubbedAttempts[email] ?? []
    }
}

private final class PasswordRecoveryAttemptWriterSpy: PasswordRecoveryAttemptWriter {
    var recordedAttempts: [PasswordRecoveryAttempt] = []

    func recordAttempt(_ attempt: PasswordRecoveryAttempt) {
        recordedAttempts.append(attempt)
    }
}
