@testable import EssentialFeed
import XCTest

final class LoginSecurityUseCaseTests: XCTestCase {
    func test_isAccountLocked_returnsFalseWhenUnderMaxAttempts() async {
        let (sut, _) = makeSUT()

        for _ in 0 ..< 4 {
            await sut.handleFailedLogin(username: "user1")
        }

        XCTAssertFalse(sut.isAccountLocked(username: "user1"))
    }

    func test_isAccountLocked_returnsTrueWhenOverMaxAttempts() async {
        let (sut, _) = makeSUT()
        let username = "user1"

        for _ in 0 ..< 5 {
            await sut.handleFailedLogin(username: username)
        }

        XCTAssertTrue(sut.isAccountLocked(username: username))
    }

    func test_resetAttempts_removesLock() async {
        let (sut, _) = makeSUT()
        let username = "user1"

        for _ in 0 ..< 5 {
            await sut.handleFailedLogin(username: username)
        }

        await sut.resetAttempts(username: username)

        XCTAssertFalse(sut.isAccountLocked(username: username))
    }

    func test_getRemainingBlockTime_returnsCorrectTime() async {
        let fixedDate = Date()
        let timeTraveler = TimeTraveler(initialDate: fixedDate)
        let blockDuration: TimeInterval = 300
        let (sut, _) = makeSUT(
            blockDuration: blockDuration,
            timeProvider: { timeTraveler.currentDate }
        )
        let username = "user1"

        for _ in 0 ..< 5 {
            await sut.handleFailedLogin(username: username)
        }

        timeTraveler.travel(by: 120)

        let expectedRemainingTime = blockDuration - 120
        let remainingTime = sut.getRemainingBlockTime(username: username)

        XCTAssertEqual(remainingTime!, expectedRemainingTime, accuracy: 0.001)
    }

    // MARK: - Helpers

    private func makeSUT(
        maxAttempts: Int = 5,
        blockDuration: TimeInterval = 300,
        timeProvider: @escaping () -> Date = { Date() },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: LoginSecurityUseCase, store: FailedLoginAttemptsStore) {
        let store = InMemoryFailedLoginAttemptsStore()
        let sut = LoginSecurityUseCase(
            store: store,
            maxAttempts: maxAttempts,
            blockDuration: blockDuration,
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
