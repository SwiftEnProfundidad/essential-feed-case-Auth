import EssentialFeed
import XCTest

final class LoginSecurityUseCaseTests: XCTestCase {
    func test_isAccountLocked_returnsFalseWhenUnderMaxAttempts() async {
        let (sut, _) = makeSUT()

        for _ in 0 ..< 4 {
            await sut.handleFailedLogin(username: "user1")
        }

        let isLocked = await sut.isAccountLocked(username: "user1")
        XCTAssertFalse(isLocked)
    }

    func test_isAccountLocked_returnsTrueWhenOverMaxAttempts() async {
        let (sut, _) = makeSUT()
        let username = "user1"

        for _ in 0 ..< 5 {
            await sut.handleFailedLogin(username: username)
        }

        let isLocked = await sut.isAccountLocked(username: username)
        XCTAssertTrue(isLocked)
    }

    func test_resetAttempts_removesLock() async {
        let (sut, _) = makeSUT()
        let username = "user1"

        for _ in 0 ..< 5 {
            await sut.handleFailedLogin(username: username)
        }

        await sut.resetAttempts(username: username)

        let isLocked = await sut.isAccountLocked(username: username)
        XCTAssertFalse(isLocked)
    }

    func test_getRemainingBlockTime_returnsCorrectTime() async {
        let fixedDate = Date()
        let timeTraveler = TimeTraveler(initialDate: fixedDate)
        let blockDuration: TimeInterval = 300
        let travelTime: TimeInterval = 120
        let expectedRemainingTime = blockDuration - travelTime
        let (sut, _) = makeSUT(
            configuration: LoginSecurityConfiguration(maxAttempts: 5, blockDuration: blockDuration, captchaThreshold: 3),
            timeProvider: { timeTraveler.currentDate }
        )
        let username = "user1"

        for _ in 0 ..< 5 {
            await sut.handleFailedLogin(username: username)
        }

        timeTraveler.travel(by: travelTime)

        guard let remainingTime = sut.getRemainingBlockTime(username: username) else {
            return XCTFail("Expected remaining time, got nil")
        }

        let lowerBound = expectedRemainingTime - 1.0
        let upperBound = expectedRemainingTime + 1.0

        XCTAssertTrue(
            (lowerBound ... upperBound).contains(remainingTime),
            "Expected remaining time to be approximately \(expectedRemainingTime), but got \(remainingTime)"
        )
    }

    // MARK: - Helpers

    private func makeSUT(
        configuration: LoginSecurityConfiguration = .default,
        timeProvider: @escaping () -> Date = { Date() },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: LoginSecurityUseCase, store: FailedLoginAttemptsStore) {
        let store = InMemoryFailedLoginAttemptsStore()
        let sut = LoginSecurityUseCase(
            store: store,
            configuration: configuration,
            timeProvider: timeProvider
        )

        trackForMemoryLeaks(store, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)

        return (sut, store)
    }

    private class TimeTraveler {
        private var current: Date

        var currentDate: Date {
            current
        }

        init(initialDate: Date = Date()) {
            self.current = initialDate
        }

        func travel(by timeInterval: TimeInterval) {
            current = current.addingTimeInterval(timeInterval)
        }
    }
}
