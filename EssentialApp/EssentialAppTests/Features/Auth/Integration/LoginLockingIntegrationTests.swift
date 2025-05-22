import EssentialApp
import EssentialFeed
import XCTest

class LoginLockingIntegrationTests: XCTestCase {
    func test_accountLocksAfterMaxFailedAttempts_andUnlocksAfterTimeout() async {
        let initialDate = Date()
        var currentDate = initialDate
        let store = FailedLoginAttemptsStoreSpy()
        let testUsername = "test@mail.com"

        let sut = makeSUT(
            store: store,
            authenticate: { _, _ in .failure(.invalidCredentials) },
            timeProvider: { currentDate }
        )

        for attempt in 1 ... 5 {
            await attemptLogin(with: sut, username: testUsername)
            XCTAssertNotNil(sut.errorMessage, "Should show error on attempt \(attempt)")
        }

        XCTAssertTrue(sut.isLoginBlocked, "Account should lock after 5 attempts")
        XCTAssertEqual(store.incrementAttemptsCallCount, 5, "Should record 5 attempts")
        XCTAssertEqual(store.capturedUsernames.last, testUsername, "Should capture correct user")

        currentDate = initialDate.addingTimeInterval(300 + 1)

        await attemptLogin(with: sut, username: testUsername)

        XCTAssertFalse(sut.isLoginBlocked, "Account should unlock after timeout")
        XCTAssertEqual(store.incrementAttemptsCallCount, 6, "Should record 6th attempt after unlock")
    }

    // MARK: - Helpers

    private func makeSUT(
        store: FailedLoginAttemptsStore = FailedLoginAttemptsStoreSpy(),
        authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError> = { _, _ in .failure(.invalidCredentials) },
        timeProvider: @escaping () -> Date = { Date() },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> LoginViewModel {
        let loginSecurity = LoginSecurityUseCase(
            store: store,
            maxAttempts: 5,
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
        password: String = "password",
        shouldFail: Bool = true
    ) async {
        sut.username = username
        sut.password = password
        await sut.login()

        if shouldFail {
            XCTAssertNotNil(sut.errorMessage, "Should show error message on failed login")
        } else {
            XCTAssertNil(sut.errorMessage, "Shouldn't show error message on successful login")
        }
    }
}
