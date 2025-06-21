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
        XCTAssertEqual(store.incrementAttemptsCallCount, 5, "Should record new attempt after unlock")
    }

    func test_resetFailedAttemptsOnSuccessfulLogin() async {
        let store = FailedLoginAttemptsStoreSpy()
        let testUsername = "test@mail.com"
        var shouldSucceed = false

        let sut = makeSUT(
            store: store,
            authenticate: { _, _ in
                if shouldSucceed {
                    .success(LoginResponse(
                        user: User(name: "Test User", email: "test@example.com"),
                        token: Token(accessToken: "valid_token", expiry: Date().addingTimeInterval(3600), refreshToken: nil)
                    ))
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

    func test_captchaDoesNotReappearInLoop_afterSuccessfulCaptchaAndSubsequentLoginFailure() async {
        let initialDate = Date()
        let currentDate = initialDate
        let store = FailedLoginAttemptsStoreSpy()
        let testUsername = "test@mail.com"
        let testPassword = "password123"
        let captchaThreshold = 3
        let captchaCoordinator = CaptchaFlowCoordinatorSpy(captchaThreshold: captchaThreshold)
        var loginErrorToReturn: LoginError = .invalidCredentials

        let sut = makeSUT(
            store: store,
            captchaThreshold: captchaThreshold,
            captchaCoordinator: captchaCoordinator,
            authenticate: { _, _ in .failure(loginErrorToReturn) },
            timeProvider: { currentDate }
        )

        for _ in 1 ... captchaThreshold {
            await attemptLogin(with: sut, username: testUsername, password: testPassword)
        }

        XCTAssertTrue(sut.shouldShowCaptcha, "CAPTCHA should be shown after \(captchaThreshold) failed attempts")

        captchaCoordinator.simulateSuccessfulValidation()

        sut.captchaToken = "valid_token"

        try? await waitForAsyncOperations()

        loginErrorToReturn = .accountLocked(remainingTime: 300)

        XCTAssertFalse(sut.shouldShowCaptcha, "CAPTCHA should be hidden after successful validation")

        XCTAssertFalse(sut.shouldShowCaptcha, "CAPTCHA should not reappear after account locked error")
    }

    // MARK: - Helpers

    private func makeSUT(
        store: FailedLoginAttemptsStore,
        maxAttempts: Int = 5,
        lockoutTime: TimeInterval = 300,
        captchaThreshold: Int = 3,
        captchaCoordinator: CaptchaFlowCoordinating? = nil,
        authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError>,
        timeProvider: @escaping () -> Date = { Date() },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> LoginViewModel {
        let loginSecurity = LoginSecurityUseCase(
            store: store,
            configuration: LoginSecurityConfiguration(maxAttempts: maxAttempts, blockDuration: lockoutTime, captchaThreshold: captchaThreshold),
            timeProvider: timeProvider
        )

        let sut = LoginViewModel(
            authenticate: authenticate,
            pendingRequestStore: nil,
            loginSecurity: loginSecurity,
            captchaFlowCoordinator: captchaCoordinator
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

    private func waitForAsyncOperations() async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
    }
}

final class CaptchaFlowCoordinatorSpy: CaptchaFlowCoordinating {
    private var validationResult: Result<Void, CaptchaError> = .failure(.networkError)
    private(set) var captchaValidationCallCount = 0
    private(set) var capturedTokens: [String] = []
    private(set) var capturedUsernames: [String] = []
    private let captchaThreshold: Int

    init(captchaThreshold: Int = 3) {
        self.captchaThreshold = captchaThreshold
    }

    func shouldTriggerCaptcha(failedAttempts: Int) -> Bool {
        return failedAttempts >= captchaThreshold
    }

    func handleCaptchaValidation(token: String, username: String) async -> Result<Void, CaptchaError> {
        captchaValidationCallCount += 1
        capturedTokens.append(token)
        capturedUsernames.append(username)
        return validationResult
    }

    func simulateSuccessfulValidation() {
        validationResult = .success(())
    }

    func simulateFailedValidation(error: CaptchaError = .invalidResponse) {
        validationResult = .failure(error)
    }
}
