import EssentialApp
import EssentialFeed
import XCTest

final class LoginIntegrationTests: XCTestCase {
    func test_loginFlow_whenMultipleFailedAttempts_shouldLockAccount() async {
        let (sut, _) = makeSUT()

        sut.username = "test@example.com"
        sut.password = "wrong_password"

        await sut.login()
        XCTAssertFalse(sut.isLoginBlocked, "Account should not be blocked after first failed attempt", file: #filePath, line: #line)

        await sut.login()
        XCTAssertTrue(sut.isLoginBlocked, "Account should be blocked after second failed attempt", file: #filePath, line: #line)
    }

    func test_loginFlow_whenAccountBlocked_shouldSuggestPasswordRecovery() async {
        let (sut, _) = makeSUT()

        sut.username = "blocked@example.com"
        sut.password = "wrong_password"

        await sut.login()
        XCTAssertFalse(sut.isLoginBlocked, "Account should not be blocked after first failed attempt", file: #filePath, line: #line)

        await sut.login()
        XCTAssertTrue(sut.isLoginBlocked, "Account should be blocked after second failed attempt", file: #filePath, line: #line)
        XCTAssertNotNil(sut.errorMessage, "Should show error message when blocked", file: #filePath, line: #line)
        XCTAssertTrue(
            sut.errorMessage?.contains("recovery") == true ||
                sut.errorMessage?.contains("forgot") == true ||
                sut.errorMessage?.contains("locked") == true,
            "Error message should suggest password recovery or show account locked. Actual: \(sut.errorMessage ?? "nil")",
            file: #filePath,
            line: #line
        )
    }

    func test_loginFlow_whenValidCredentials_shouldSucceedAndClearErrors() async {
        let (sut, _) = makeSUT(authenticateResult: .success(LoginResponse(token: "test-token")))

        sut.username = "valid@example.com"
        sut.password = "correct_password"

        await sut.login()

        XCTAssertTrue(sut.loginSuccess, "Login should succeed with valid credentials", file: #filePath, line: #line)
        XCTAssertNil(sut.errorMessage, "Error message should be cleared on success. Actual: \(sut.errorMessage ?? "nil")", file: #filePath, line: #line)
        XCTAssertFalse(sut.isLoginBlocked, "Account should not be blocked on success", file: #filePath, line: #line)
    }

    func test_loginFlow_whenBlockedAccountTimeExpires_shouldAllowRetry() async {
        let (sut, _) = makeSUT()

        sut.username = "timeout@example.com"
        sut.password = "wrong_password"

        await sut.login()
        await sut.login()
        XCTAssertTrue(sut.isLoginBlocked, "Account should be blocked initially after 2 attempts", file: #filePath, line: #line)

        try? await Task.sleep(nanoseconds: 1_100_000_000)

        await sut.login()
        XCTAssertFalse(sut.isLoginBlocked, "Account should be unblocked after timeout", file: #filePath, line: #line)
    }

    func test_loginWithValidCredentials_integratesFullChain_andNotifiesSuccessObserver() async {
        let (successObserver, apiSpy) = makeIntegrationComponents()

        apiSpy.stubbedResult = Result<LoginResponse, LoginError>.success(LoginResponse(token: "expected_token"))

        let sut = makeIntegrationSUT(successObserver: successObserver, apiSpy: apiSpy)

        sut.username = "valid@email.com"
        sut.password = "validpass123"

        await sut.login()

        XCTAssertEqual(successObserver.notificationCount, 1, "Should notify success observer", file: #filePath, line: #line)
        XCTAssertNotNil(successObserver.lastResponse, "Should receive login response", file: #filePath, line: #line)
        XCTAssertEqual(successObserver.lastResponse?.token, "expected_token", "Should receive correct token", file: #filePath, line: #line)
    }

    // MARK: - Helpers

    private func makeSUT(
        authenticateResult: Result<LoginResponse, LoginError> = .failure(.invalidCredentials),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: LoginViewModel,
        notifierSpy: LoginEventNotifierSpy
    ) {
        let configuration = LoginSecurityConfiguration(maxAttempts: 2, blockDuration: 1, captchaThreshold: 2)
        let loginSecurity = LoginSecurityUseCase(store: InMemoryFailedLoginAttemptsStore(), configuration: configuration)

        let successObserverSpy = LoginSuccessObserverSpy()
        let failureObserverSpy = LoginFailureObserverSpy()
        let notifierSpy = LoginEventNotifierSpy(successObserver: successObserverSpy, failureObserver: failureObserverSpy)

        let sut = LoginViewModel(
            authenticate: { _, _ in authenticateResult },
            loginSecurity: loginSecurity
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(loginSecurity, file: file, line: line)
        trackForMemoryLeaks(notifierSpy, file: file, line: line)
        trackForMemoryLeaks(successObserverSpy, file: file, line: line)
        trackForMemoryLeaks(failureObserverSpy, file: file, line: line)

        return (sut, notifierSpy)
    }

    private func makeIntegrationComponents() -> (LoginSuccessObserverSpy, UserLoginAPISpy) {
        let successObserver = LoginSuccessObserverSpy()
        let apiSpy = UserLoginAPISpy()
        return (successObserver, apiSpy)
    }

    private func makeIntegrationSUT(successObserver: LoginSuccessObserverSpy, apiSpy: UserLoginAPISpy) -> LoginViewModel {
        let configuration = LoginSecurityConfiguration(maxAttempts: 3, blockDuration: 300, captchaThreshold: 2)
        let loginSecurity = LoginSecurityUseCase(store: InMemoryFailedLoginAttemptsStore(), configuration: configuration)

        let sut = LoginViewModel(
            authenticate: { username, password in
                let credentials = LoginCredentials(email: username, password: password)
                let result = await apiSpy.login(with: credentials)
                switch result {
                case let .success(response):
                    successObserver.didLoginSuccessfully(response: response)
                    return .success(response)
                case let .failure(error):
                    return .failure(error)
                }
            },
            loginSecurity: loginSecurity
        )
        trackForMemoryLeaks(successObserver, file: #filePath, line: #line)
        trackForMemoryLeaks(apiSpy, file: #filePath, line: #line)
        trackForMemoryLeaks(loginSecurity, file: #filePath, line: #line)
        trackForMemoryLeaks(sut, file: #filePath, line: #line)
        return sut
    }
}

// MARK: - Test Helpers

private final class InMemoryFailedLoginAttemptsStore: FailedLoginAttemptsStore {
    private var attemptCounts: [String: Int] = [:]
    private var lastAttemptTimestamps: [String: Date] = [:]
    private let lock = NSLock()

    private func performSynchronizedUpdate(_ update: () -> Void) {
        lock.lock()
        update()
        lock.unlock()
    }

    func incrementAttempts(for username: String) async {
        performSynchronizedUpdate {
            self.attemptCounts[username, default: 0] += 1
            self.lastAttemptTimestamps[username] = Date()
        }
    }

    func resetAttempts(for username: String) async {
        attemptCounts[username] = nil
        lastAttemptTimestamps[username] = nil
    }

    func getAttempts(for username: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return self.attemptCounts[username] ?? 0
    }

    func lastAttemptTime(for username: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return self.lastAttemptTimestamps[username]
    }
}
