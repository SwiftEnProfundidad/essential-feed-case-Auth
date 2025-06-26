import EssentialApp
import EssentialFeed
import XCTest

class LoginLockingIntegrationTests: XCTestCase {
    func test_accountLocksAfterMaxFailedAttempts_andUnlocksAfterTimeout() async {
        let initialDate = Date()
        var currentDate = initialDate
        let store = TimeControlledFailedLoginAttemptsStoreSpy(timeProvider: { currentDate })
        let testUsername = "test@mail.com"

        let sut = makeSUT(
            store: store,
            authenticate: { _, _ in .failure(.invalidCredentials) },
            timeProvider: { currentDate }
        )

        for attempt in 1 ... 5 {
            await attemptLogin(with: sut, username: testUsername)
            await Task.yield()
            XCTAssertNotNil(sut.currentNotification, "Should show error on attempt \(attempt)")
        }

        await Task.yield()
        XCTAssertTrue(sut.isLoginBlocked, "Account should lock after 5 attempts")
        XCTAssertEqual(store.incrementAttemptsCallCount, 5, "Should record 5 attempts")
        XCTAssertEqual(store.capturedUsernames.last, testUsername, "Should capture correct user")

        currentDate = initialDate.addingTimeInterval(300 + 1)

        await attemptLogin(with: sut, username: testUsername)

        await Task.yield()
        XCTAssertFalse(sut.isLoginBlocked, "Account should unlock after timeout")
        XCTAssertEqual(store.incrementAttemptsCallCount, 6, "Should record 6th attempt after unlock")
    }

    // MARK: - Helpers

    private func makeSUT(
        store: FailedLoginAttemptsStore = TimeControlledFailedLoginAttemptsStoreSpy(),
        authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError> = { _, _ in .failure(.invalidCredentials) },
        timeProvider: @escaping () -> Date = { Date() },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> LoginViewModel {
        let configuration = LoginSecurityConfiguration(maxAttempts: 5, blockDuration: 300, captchaThreshold: 3)
        let loginSecurity = LoginSecurityUseCase(
            store: store,
            configuration: configuration,
            timeProvider: timeProvider
        )
        let sut = LoginViewModel(
            authenticate: authenticate,
            pendingRequestStore: nil,
            loginSecurity: loginSecurity,
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(loginSecurity, file: file, line: line)
        trackForMemoryLeaks(store as AnyObject, file: file, line: line)
        return sut
    }

    private func attemptLogin(
        with sut: LoginViewModel,
        username: String = "test@mail.com",
        password: String = "password"
    ) async {
        sut.username = username
        sut.password = password
        await sut.login()
    }
}
