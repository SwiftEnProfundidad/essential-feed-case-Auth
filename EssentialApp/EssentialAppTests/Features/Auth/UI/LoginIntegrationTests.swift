import EssentialApp
import EssentialFeed
import XCTest

final class LoginIntegrationTests: XCTestCase {
    func test_loginFlow_whenMultipleFailedAttempts_shouldLockAccount() async {
        let (sut, _) = makeSUT()

        sut.username = "test@example.com"
        sut.password = "wrong_password"

        await sut.login()
        XCTAssertFalse(sut.isLoginBlocked, "Account should not be blocked after first failed attempt")

        await sut.login()
        XCTAssertTrue(sut.isLoginBlocked, "Account should be blocked after second failed attempt")
    }

    func test_loginFlow_whenAccountBlocked_shouldSuggestPasswordRecovery() async {
        let (sut, _) = makeSUT(maxAttempts: 1)

        sut.username = "blocked@example.com"
        sut.password = "wrong_password"

        await sut.login()

        XCTAssertTrue(sut.isLoginBlocked, "Account should be blocked after failed attempt")
        XCTAssertNotNil(sut.errorMessage, "Should show error message when blocked")
        XCTAssertTrue(
            sut.errorMessage?.contains("recovery") == true ||
                sut.errorMessage?.contains("forgot") == true,
            "Error message should suggest password recovery"
        )
    }

    func test_loginFlow_whenValidCredentials_shouldSucceedAndClearErrors() async {
        let (sut, _) = makeSUT(authenticateResult: .success(LoginResponse(token: "valid-token")))

        sut.username = "valid@example.com"
        sut.password = "correct_password"

        await sut.login()

        XCTAssertTrue(sut.loginSuccess, "Login should succeed with valid credentials")
        XCTAssertNil(sut.errorMessage, "Error message should be cleared on success")
        XCTAssertFalse(sut.isLoginBlocked, "Account should not be blocked on success")
    }

    func test_loginFlow_whenBlockedAccountTimeExpires_shouldAllowRetry() async {
        let (sut, _) = makeSUT(maxAttempts: 1, blockDuration: 1)

        sut.username = "timeout@example.com"
        sut.password = "wrong_password"

        await sut.login()
        XCTAssertTrue(sut.isLoginBlocked, "Account should be blocked initially")

        try? await Task.sleep(nanoseconds: 1_100_000_000)

        await sut.login()
        XCTAssertFalse(sut.isLoginBlocked, "Account should be unblocked after timeout")
    }

    func test_loginWithValidCredentials_integratesFullChain_andNotifiesSuccessObserver() async {
        let (successObserver, apiSpy) = makeIntegrationComponents()

        apiSpy.stubbedResult = Result<LoginResponse, LoginError>.success(LoginResponse(token: "expected_token"))

        let sut = makeIntegrationSUT(successObserver: successObserver, apiSpy: apiSpy)

        sut.username = "valid@email.com"
        sut.password = "validpass123"

        await sut.login()

        XCTAssertEqual(successObserver.notificationCount, 1, "Should notify success observer")
        XCTAssertNotNil(successObserver.lastResponse, "Should receive login response")
        XCTAssertEqual(successObserver.lastResponse?.token, "expected_token", "Should receive correct token")
    }

    // MARK: - Helpers

    private func makeSUT(
        authenticateResult: Result<LoginResponse, LoginError> = .failure(.invalidCredentials),
        maxAttempts: Int = 2,
        blockDuration: TimeInterval = 300,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: LoginViewModel, store: InMemoryFailedLoginAttemptsStore) {
        let store = InMemoryFailedLoginAttemptsStore()
        let configuration = LoginSecurityConfiguration(maxAttempts: maxAttempts, blockDuration: blockDuration)
        let securityUseCase = LoginSecurityUseCase(store: store, configuration: configuration)

        let sut = LoginViewModel(
            authenticate: { _, _ in authenticateResult },
            loginSecurity: securityUseCase
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(store, file: file, line: line)

        return (sut, store)
    }

    private func makeIntegrationComponents() -> (LoginSuccessObserverSpy, UserLoginAPISpy) {
        let successObserver = LoginSuccessObserverSpy()
        let apiSpy = UserLoginAPISpy()
        return (successObserver, apiSpy)
    }

    private func makeIntegrationSUT(successObserver: LoginSuccessObserverSpy, apiSpy: UserLoginAPISpy) -> LoginViewModel {
        let validator = LoginCredentialsValidator()
        let failedLoginStore = InMemoryFailedLoginAttemptsStore()
        let securityUseCase = LoginSecurityUseCase(store: failedLoginStore, maxAttempts: 3, blockDuration: 300)
        let tokenStorage = TokenStorageSpy()
        let offlineStore = OfflineLoginStoreSpy()
        let config = UserLoginConfiguration(maxFailedAttempts: 3, lockoutDuration: 300, tokenDuration: 3600)
        let persistence = LoginPersistenceSpy(tokenStorage: tokenStorage, offlineStore: offlineStore, config: config)
        let loginService = DefaultLoginService(validator: validator, securityUseCase: securityUseCase, api: apiSpy, persistence: persistence, config: config)
        let useCase = UserLoginUseCase(loginService: loginService)

        let sut = LoginViewModel(authenticate: { username, password in
            let credentials = LoginCredentials(email: username, password: password)
            let result = await useCase.execute(credentials)
            switch result {
            case let .success(response):
                await successObserver.notify(response)
                return .success(response)
            case let .failure(error):
                return .failure(error)
            }
        })

        return sut
    }
}

// MARK: - Test Helpers

private final class InMemoryFailedLoginAttemptsStore: FailedLoginAttemptsReader, FailedLoginAttemptsWriter {
    private var attemptCounts: [String: Int] = [:]
    private var lastAttemptTimestamps: [String: Date] = [:]

    func incrementAttempts(for username: String) async {
        attemptCounts[username, default: 0] += 1
        lastAttemptTimestamps[username] = Date()
    }

    func resetAttempts(for username: String) async {
        attemptCounts[username] = nil
        lastAttemptTimestamps[username] = nil
    }

    func getAttempts(for username: String) -> Int {
        attemptCounts[username] ?? 0
    }

    func lastAttemptTime(for username: String) -> Date? {
        lastAttemptTimestamps[username]
    }
}
