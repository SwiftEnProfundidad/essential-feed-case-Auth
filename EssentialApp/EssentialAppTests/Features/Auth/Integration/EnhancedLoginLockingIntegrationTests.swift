import EssentialApp
import EssentialFeed
import XCTest

final class EnhancedLoginLockingIntegrationTests: XCTestCase {
    func test_accountLocksAfterMaxFailedAttempts_andUnlocksAfterTimeout() async {
        let initialDate = Date()
        var currentDate = initialDate
        let store = FailedLoginAttemptsStoreSpy()
        let testUsername = "test@mail.com"
        let maxAttempts = 5
        let lockoutTime: TimeInterval = 300

        let sut = makeSUT(
            store: store,
            maxAttempts: maxAttempts,
            lockoutTime: lockoutTime,
            authenticate: { _, _ in .failure(.invalidCredentials) },
            timeProvider: { currentDate }
        )

        for attempt in 1 ..< maxAttempts {
            await attemptLogin(with: sut, username: testUsername)
            XCTAssertNotNil(sut.errorMessage, "Should show error on attempt \(attempt)")
            XCTAssertFalse(sut.isLoginBlocked, "Account should not be locked after \(attempt) attempts")
        }

        await attemptLogin(with: sut, username: testUsername)
        XCTAssertTrue(sut.isLoginBlocked, "Account should lock after \(maxAttempts) attempts")
        XCTAssertEqual(store.incrementAttemptsCallCount, maxAttempts, "Should record \(maxAttempts) attempts")
        XCTAssertTrue(store.capturedUsernames.contains(testUsername), "Should capture correct username")
        XCTAssertNotNil(sut.errorMessage, "Should show lockout message")

        await attemptLogin(with: sut, username: testUsername)
        XCTAssertEqual(store.incrementAttemptsCallCount, maxAttempts, "Should not increment attempts while locked")

        currentDate = initialDate.addingTimeInterval(lockoutTime - 1)
        await attemptLogin(with: sut, username: testUsername)
        XCTAssertTrue(sut.isLoginBlocked, "Account should still be locked")

        currentDate = initialDate.addingTimeInterval(lockoutTime + 1)
        await attemptLogin(with: sut, username: testUsername)

        XCTAssertFalse(sut.isLoginBlocked, "Account should unlock after timeout")
        XCTAssertEqual(store.incrementAttemptsCallCount, maxAttempts + 1, "Should record new attempt after unlock")
    }

    func test_resetFailedAttemptsOnSuccessfulLogin() async {
        let store = FailedLoginAttemptsStoreSpy()
        let testUsername = "test@mail.com"
        var shouldSucceed = false

        let sut = makeSUT(
            store: store,
            authenticate: { _, _ in
                if shouldSucceed {
                    .success(LoginResponse(token: "valid_token"))
                } else {
                    .failure(.invalidCredentials)
                }
            }
        )

        for _ in 1 ... 3 {
            await attemptLogin(with: sut, username: testUsername)
        }

        shouldSucceed = true
        await attemptLogin(with: sut, username: testUsername)

        XCTAssertEqual(store.resetAttemptsCallCount, 1, "Should reset failed attempts on successful login")
        XCTAssertEqual(store.capturedUsernames.last, testUsername, "Should reset attempts for correct user")
        XCTAssertNil(sut.errorMessage, "Should not show error after successful login")
    }

    // MARK: - Helpers

    private func makeSUT(
        store: FailedLoginAttemptsStore,
        maxAttempts: Int = 5,
        lockoutTime: TimeInterval = 300,
        authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError>,
        timeProvider: @escaping () -> Date = { Date() },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> LoginViewModel {
        let loginSecurity = LoginSecurityUseCase(
            store: store,
            configuration: LoginSecurityConfiguration(maxAttempts: maxAttempts, blockDuration: lockoutTime),
            timeProvider: timeProvider
        )

        let sut = LoginViewModel(
            authenticate: authenticate,
            pendingRequestStore: nil,
            loginSecurity: loginSecurity
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(loginSecurity, file: file, line: line)

        return sut
    }

    private func attemptLogin(
        with sut: LoginViewModel, username: String, password: String = "any",
        file _: StaticString = #filePath, line _: UInt = #line
    ) async {
        sut.username = username
        sut.password = password
        await sut.login()
    }
}
