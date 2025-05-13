
import Combine
import EssentialApp
import EssentialFeed
import XCTest

final class LoginViewTests: XCTestCase {
    func test_login_withInvalidEmail_showsValidationError() async {
        let viewModel = makeSUT(authenticate: { _, _ in .failure(.invalidEmailFormat) }, blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "invalid-email"
        viewModel.password = "password"

        await viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "Email format is invalid.")
    }

    func test_login_withEmptyPassword_showsValidationError() async {
        let viewModel = makeSUT(authenticate: { _, _ in .failure(.invalidPasswordFormat) }, blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = ""
        await viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "Password cannot be empty.")
    }

    func test_login_withValidCredentials_triggersAuthentication() async {
        let exp = expectation(description: "Authentication triggered")
        let viewModel = makeSUT(authenticate: { username, password in
            XCTAssertEqual(username, "user@email.com")
            XCTAssertEqual(password, "password")
            exp.fulfill()
            return .success(LoginResponse(token: "token"))
        }, blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        await viewModel.login()
        await fulfillment(of: [exp], timeout: 1.0)
    }

    func test_login_withInvalidCredentials_showsAuthenticationError() async {
        let viewModel = makeSUT(blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = "wrongpass"
        await viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "Invalid credentials.")
    }

    func test_login_success_showsSuccessFeedback() async {
        let viewModel = makeSUT(authenticate: { _, _ in .success(LoginResponse(token: "token")) }, blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertTrue(viewModel.loginSuccess)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoginBlocked)
    }

    func test_login_networkError_showsNetworkErrorMessage() async {
        let viewModel = makeSUT(authenticate: { _, _ in .failure(.network) }, blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "Could not connect. Please try again.")
    }

    func test_login_error_showsErrorFeedback() async {
        let viewModel = makeSUT(authenticate: { _, _ in .failure(.unknown) }, blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "Something went wrong. Please try again.")
    }

    func test_editingUsernameOrPassword_clearsErrorMessage() async {
        let viewModel = makeSUT(blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = "wrongpass"
        await viewModel.login()
        XCTAssertNotNil(viewModel.errorMessage, "Expected errorMessage to be present after failed login")

        viewModel.username = "new@email.com"
        XCTAssertNil(viewModel.errorMessage, "Expected errorMessage to be nil after editing username, but got: \(viewModel.errorMessage ?? "nil")")

        viewModel.username = "user@email.com"
        viewModel.password = "wrongpass"
        await viewModel.login()
        XCTAssertNotNil(viewModel.errorMessage, "Expected errorMessage to be present after failed login")

        viewModel.password = "newpassword"
        XCTAssertNil(viewModel.errorMessage, "Expected errorMessage to be nil after editing password")
    }

    func test_loginSuccessFlag_isTrueAfterSuccessAndFalseAfterFailure() async {
        let viewModel = makeSUT(authenticate: { _, _ in .success(LoginResponse(token: "token")) }, blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertTrue(viewModel.loginSuccess, "Expected loginSuccess to be true after successful login")

        let failingVM = makeSUT()
        failingVM.username = "user@email.com"
        failingVM.password = "wrongpass"
        await failingVM.login()
        XCTAssertFalse(failingVM.loginSuccess, "Expected loginSuccess to be false after failed login")
    }

    func test_successfulLogin_clearsPreviousErrorMessage() async {
        let failingViewModel = makeSUT()
        failingViewModel.username = "user@email.com"
        failingViewModel.password = "wrongpass"
        await failingViewModel.login()
        XCTAssertNotNil(failingViewModel.errorMessage, "Expected errorMessage to be present after failed login")

        let successViewModel = makeSUT(authenticate: { _, _ in .success(LoginResponse(token: "token")) })
        successViewModel.username = "user@email.com"
        successViewModel.password = "password"
        await successViewModel.login()
        XCTAssertNil(successViewModel.errorMessage, "Expected errorMessage to be nil after successful login, but got: \(successViewModel.errorMessage ?? "nil")")
        XCTAssertTrue(successViewModel.loginSuccess, "Expected loginSuccess to be true after successful login")
    }

    func test_usernameAndPassword_arePublishedAndObservable() async {
        let viewModel = makeSUT(blockMessageProvider: DefaultLoginBlockMessageProvider())
        let expectedUsername = "test@email.com"
        let expectedPassword = "testpass123"
        viewModel.username = expectedUsername
        viewModel.password = expectedPassword
        XCTAssertEqual(viewModel.username, expectedUsername, "Expected username to be published and observable")
        XCTAssertEqual(viewModel.password, expectedPassword, "Expected password to be published and observable")
    }

    func test_onSuccessAlertDismissed_executesCallback() async {
        let viewModel = makeSUT(authenticate: { _, _ in .success(LoginResponse(token: "token")) }, blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertTrue(viewModel.loginSuccess, "Expected loginSuccess to be true after successful login")

        var callbackCalled = false
        viewModel.onAuthenticated = {
            callbackCalled = true
        }
        viewModel.onSuccessAlertDismissed()
        XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false after dismissing alert")
        XCTAssertTrue(callbackCalled, "Expected onAuthenticated callback to be called after alert dismissed")
    }

    func test_initialState_isClean() async {
        let viewModel = makeSUT(blockMessageProvider: DefaultLoginBlockMessageProvider())
        XCTAssertNil(viewModel.errorMessage, "Expected errorMessage to be nil on initial state")
        XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false on initial state")
        XCTAssertEqual(viewModel.username, "", "Expected username to be empty on initial state")
        XCTAssertEqual(viewModel.password, "", "Expected password to be empty on initial state")
    }

    func test_login_withEmptyFields_showsValidationError() async {
        let viewModel = makeSUT(blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = ""
        viewModel.password = ""
        await viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "Email format is invalid.", "Expected validation error when username is empty")
        XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false when login fails due to validation")
    }

    func test_login_callsAuthenticateWithTrimmedUsername() async {
        var receivedUsername: String?
        let viewModel = makeSUT(authenticate: { username, _ in
            receivedUsername = username
            return .failure(.invalidCredentials)
        }, blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "   user@email.com   "
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertEqual(receivedUsername, "user@email.com", "Expected authenticate to be called with trimmed username")
    }

    func test_viewModel_deallocation_doesNotRetainClosure() async {
        var viewModel: LoginViewModel? = makeSUT(authenticate: { _, _ in .failure(.invalidCredentials) })
        weak var weakViewModel = viewModel
        viewModel?.onAuthenticated = { _ = weakViewModel }
        viewModel = nil
        XCTAssertNil(weakViewModel, "ViewModel should be deallocated and not retain closures")
    }

    func test_login_doesNotTriggerAuthenticatedOnFailure() async {
        let viewModel = makeSUT(authenticate: { _, _ in .failure(.invalidCredentials) }, blockMessageProvider: DefaultLoginBlockMessageProvider())
        var authenticatedCalled = false
        let cancellable = viewModel.authenticated.sink { _ in
            authenticatedCalled = true
        }
        viewModel.username = "user@email.com"
        viewModel.password = "fail"
        await viewModel.login()
        XCTAssertFalse(authenticatedCalled, "Expected authenticated event NOT to be sent after failed login")
        _ = cancellable
    }

    func test_errorMessage_isClearedOnLoginSuccess() async {
        let viewModel = makeSUT(authenticate: { _, password in
            if password == "fail" {
                .failure(.invalidCredentials)
            } else {
                .success(LoginResponse(token: "token"))
            }
        }, blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = "fail"
        await viewModel.login()
        XCTAssertNotNil(viewModel.errorMessage, "Expected error message after failed login")
        viewModel.password = "pass"
        await viewModel.login()
        XCTAssertNil(viewModel.errorMessage, "Expected error message to be cleared after successful login")
    }

    func test_multipleLoginAttempts_onlyLastResultMatters() async {
        let exp = expectation(description: "Only last login result is reflected")
        exp.expectedFulfillmentCount = 2
        actor CompletionsStore {
            private(set) var completions: [Result<LoginResponse, LoginError>] = []
            func append(_ value: Result<LoginResponse, LoginError>) {
                completions.append(value)
            }
        }
        let completionsStore = CompletionsStore()
        let viewModel = makeSUT(authenticate: { _, password in
            if password == "first" {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                await completionsStore.append(.failure(.invalidCredentials))
                exp.fulfill()
                return .failure(.invalidCredentials)
            } else {
                await completionsStore.append(.success(LoginResponse(token: "token")))
                exp.fulfill()
                return .success(LoginResponse(token: "token"))
            }
        }, blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = "first"
        let firstLogin = Task { await viewModel.login() }
        // Launch second login almost immediately
        viewModel.password = "second"
        let secondLogin = Task { await viewModel.login() }
        await fulfillment(of: [exp], timeout: 1.0)
        await firstLogin.value
        await secondLogin.value
        XCTAssertTrue(viewModel.loginSuccess, "Expected loginSuccess to be true only for the last login attempt")
        XCTAssertNil(viewModel.errorMessage, "Expected errorMessage to be nil after last successful login")
    }

    func test_login_withInvalidPasswordFormat_showsValidationError() async {
        let viewModel = makeSUT(blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = "short"
        await viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "Invalid credentials.", "Expected validation error when password format is invalid")
        XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false when login fails due to invalid password format")
    }

    func test_login_withWhitespacePassword_showsValidationError() async {
        let viewModel = makeSUT(blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = "    "
        await viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "Password cannot be empty.", "Expected validation error when password is only whitespace")
        XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false when login fails due to validation")
    }

    func test_errorMessage_isClearedOnEditingFieldsAfterNetworkError() async {
        let viewModel = makeSUT(authenticate: { _, _ in .failure(.network) }, blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "Could not connect. Please try again.", "Expected network error message after failed login")

        viewModel.username = "user2@email.com"
        XCTAssertNil(viewModel.errorMessage, "Expected error message to be cleared after editing username")

        viewModel.username = "user@email.com"
        await viewModel.login()

        viewModel.password = "newpassword"
        XCTAssertNil(viewModel.errorMessage, "Expected error message to be cleared after editing password")
    }

    func test_login_withWhitespaceUsername_showsValidationError() async {
        let viewModel = makeSUT(blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "    "
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "Email format is invalid.", "Expected validation error when username is only whitespace")
        XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false when login fails due to validation")
    }

    func test_loginSuccess_sendsAuthenticatedEvent() async {
        let viewModel = makeSUT(authenticate: { _, _ in .success(LoginResponse(token: "token")) }, blockMessageProvider: DefaultLoginBlockMessageProvider())
        var authenticatedCalled = false
        let cancellable = viewModel.authenticated.sink { _ in
            authenticatedCalled = true
        }
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertTrue(authenticatedCalled, "Expected authenticated event to be sent after successful login")
        _ = cancellable
    }

    func test_login_networkError_storesPendingRequest_and_canRetryLater() async {
        // Arrange
        let pendingStore = InMemoryPendingRequestStore<LoginRequest>()
        var authenticateCalls: [(String, String)] = []
        let viewModel = LoginViewModel(
            authenticate: { (username: String, password: String) -> Result<LoginResponse, LoginError> in
                authenticateCalls.append((username, password))
                return .failure(LoginError.network)
            },
            pendingRequestStore: AnyLoginRequestStore(pendingStore)
        )
        viewModel.username = "user@email.com"
        viewModel.password = "password"

        await viewModel.login()

        XCTAssertEqual(pendingStore.loadAll(), [LoginRequest(username: "user@email.com", password: "password")])

        viewModel.authenticate = { (username: String, password: String) -> Result<LoginResponse, LoginError> in
            authenticateCalls.append((username, password))
            return .success(LoginResponse(token: "token"))
        }

        await viewModel.retryPendingRequests()

        XCTAssertEqual(pendingStore.loadAll(), [])
        XCTAssertTrue(viewModel.loginSuccess)
        XCTAssertEqual(authenticateCalls.count, 2)
    }

    func test_login_blocksAfterMaxFailedAttempts() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let maxAttempts = 3
        let viewModel = makeSUT(failedAttemptsStore: spyStore, maxFailedAttempts: maxAttempts, blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@test.com"
        viewModel.password = "wrong-password"

        for _ in 1 ... maxAttempts {
            await viewModel.login()
        }

        XCTAssertTrue(viewModel.isLoginBlocked, "Expected account to be locked after max failed attempts")
        XCTAssertEqual(viewModel.errorMessage, DefaultLoginBlockMessageProvider().message(forAttempts: maxAttempts, maxAttempts: maxAttempts))
    }

    func test_login_appliesIncrementalDelayAfterMaxAttempts() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let maxAttempts = 3
        let viewModel = makeSUT(
            failedAttemptsStore: spyStore,
            maxFailedAttempts: maxAttempts,
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        viewModel.username = "user@test.com"
        viewModel.password = "wrong-password"

        for _ in 1 ..< maxAttempts {
            await viewModel.login()
        }

        let startTime = Date()
        await viewModel.login()
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertTrue(viewModel.isLoginBlocked, "Account should be locked after max failed attempts")
        XCTAssertGreaterThanOrEqual(elapsed, 0.5, "Expected minimum delay of 0.5 seconds but got \(elapsed)")

        let nextStart = Date()
        await viewModel.login()
        let nextElapsed = Date().timeIntervalSince(nextStart)
        XCTAssertLessThan(nextElapsed, 0.5, "No delay should be applied after account is already blocked")
    }

    func test_login_showRecoveryOptionWhenBlocked() async {
        let maxAttempts = 1
        let viewModel = makeSUT(maxFailedAttempts: maxAttempts, blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@test.com"
        viewModel.password = "wrong-password"
        await viewModel.login()
        XCTAssertTrue(viewModel.errorMessage?.contains("reset your password") ?? false, "Should show recovery option when blocked")
    }

    func test_fullLockFlow_withPasswordRecovery() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let navigationSpy = NavigationSpy()
        let maxAttempts = 3
        let viewModel = makeSUT(
            failedAttemptsStore: spyStore,
            maxFailedAttempts: maxAttempts,
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        viewModel.navigation = navigationSpy
        viewModel.username = "user@test.com"
        viewModel.password = "wrong-password"

        for _ in 1 ... maxAttempts {
            await viewModel.login()
        }

        XCTAssertTrue(viewModel.isLoginBlocked, "Account should be locked after \(maxAttempts) attempts")
        viewModel.handleRecoveryTap()
        XCTAssertEqual(navigationSpy.recoveryScreenShown, true, "Should navigate to recovery screen")
    }

    func test_login_resetsAttemptsOnSuccess() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        var callCount = 0
        let viewModel = makeSUT(
            authenticate: { _, _ in
                callCount += 1
                if callCount == 1 {
                    return .failure(.invalidCredentials)
                } else {
                    return .success(LoginResponse(token: "any"))
                }
            },
            failedAttemptsStore: spyStore,
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )

        viewModel.username = "user@test.com"
        viewModel.password = "wrong-password"
        await viewModel.login()

        viewModel.password = "correct-password"
        await viewModel.login()

        XCTAssertEqual(spyStore.resetAttemptsCallCount, 1)
        XCTAssertEqual(spyStore.capturedUsernames.last, "user@test.com")
        XCTAssertEqual(spyStore.attempts["user@test.com"], 0)
    }

    func test_unlockAfterRecovery_resetsBlockState() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let viewModel = makeSUT(
            failedAttemptsStore: spyStore,
            maxFailedAttempts: 3
        )

        viewModel.username = "user@test.com"
        viewModel.password = "wrong-password"
        for _ in 1 ... 3 {
            await viewModel.login()
        }
        XCTAssertTrue(viewModel.isLoginBlocked, "Account should be locked after 3 failed attempts")

        viewModel.unlockAfterRecovery()

        XCTAssertFalse(viewModel.isLoginBlocked, "Account should unlock after calling unlockAfterRecovery()")
        XCTAssertNil(viewModel.errorMessage, "Error message should be nil after unlock")
        XCTAssertEqual(spyStore.resetAttemptsCallCount, 1, "resetAttempts should be called exactly once")
    }

    func test_successfulLoginAfter4FailedAttempts_resetsCounter() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let viewModel = makeSUT(
            failedAttemptsStore: spyStore,
            maxFailedAttempts: 5
        )

        viewModel.username = "user@test.com"
        viewModel.password = "wrong-pass"
        for _ in 1 ... 4 {
            await viewModel.login()
        }
        XCTAssertEqual(spyStore.attempts["user@test.com"], 4, "Should record 4 failed attempts")

        viewModel.password = "correct-pass"
        viewModel.authenticate = { _, _ in .success(LoginResponse(token: "valid-token")) }
        await viewModel.login()

        XCTAssertEqual(spyStore.resetAttemptsCallCount, 1, "Should reset counter after success")
        XCTAssertEqual(spyStore.attempts["user@test.com"], 0, "Counter should be 0 after success")
    }

    func test_failedAttemptAfterUnlock_resetsCounterAgain() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let viewModel = makeSUT(
            failedAttemptsStore: spyStore,
            maxFailedAttempts: 3
        )

        viewModel.username = "user@test.com"
        viewModel.password = "wrong-pass"
        for _ in 1 ... 3 {
            await viewModel.login()
        }
        XCTAssertTrue(viewModel.isLoginBlocked, "Account should lock after 3 failed attempts")

        viewModel.unlockAfterRecovery()
        XCTAssertFalse(viewModel.isLoginBlocked, "Account should unlock after recovery")

        await viewModel.login()

        XCTAssertEqual(spyStore.attempts["user@test.com"], 1, "Counter should restart at 1 after unlock")
        XCTAssertEqual(spyStore.incrementAttemptsCallCount, 4, "Should increment attempts for new failures")
    }

    func test_multipleLockUnlockCycles_handlesCountersCorrectly() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let viewModel = makeSUT(
            failedAttemptsStore: spyStore,
            maxFailedAttempts: 3
        )

        viewModel.username = "user@test.com"
        viewModel.password = "wrong-pass"
        for _ in 1 ... 3 {
            await viewModel.login()
        } // Bloquea
        XCTAssertTrue(viewModel.isLoginBlocked)
        viewModel.unlockAfterRecovery()

        for _ in 1 ... 3 {
            await viewModel.login()
        } // Bloquea de nuevo
        XCTAssertTrue(viewModel.isLoginBlocked)
        viewModel.unlockAfterRecovery()

        XCTAssertEqual(spyStore.resetAttemptsCallCount, 2, "Should reset attempts twice")
        XCTAssertEqual(spyStore.incrementAttemptsCallCount, 6, "Should increment attempts for all failures")
        XCTAssertEqual(spyStore.attempts["user@test.com"], 0, "Final counter should be zero")
    }

    func test_blockMessageProvider_showsContextualMessages() {
        let provider = DefaultLoginBlockMessageProvider()

        let maxAttemptsMessage = provider.messageForMaxAttemptsReached()
        XCTAssertEqual(maxAttemptsMessage, "Too many attempts. Please wait 5 minutes or reset your password.")

        let invalidCredentialsMessage = provider.message(for: .invalidCredentials)
        XCTAssertEqual(invalidCredentialsMessage, "Invalid credentials.")
    }

    func test_concurrentIncrementAttempts_threadSafety() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let viewModel = makeSUT(
            authenticate: { _, _ in .failure(.invalidCredentials) }, failedAttemptsStore: spyStore,
            maxFailedAttempts: 100
        )

        viewModel.username = "user@test.com"
        viewModel.password = "wrong-pass"

        await withTaskGroup(of: Void.self) { group in
            for _ in 1 ... 100 {
                group.addTask { await viewModel.login() }
            }
        }

        XCTAssertEqual(spyStore.incrementAttemptsCallCount, 100, "Should handle all concurrent attempts")
    }

    func test_loginViewModel_doesNotLeakMemory() {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        var sut: LoginViewModel? = makeSUT(failedAttemptsStore: spyStore)

        weak var weakSUT = sut
        sut = nil

        XCTAssertNil(weakSUT, "ViewModel should be deallocated")
    }

    func test_errorState_clearsAfterNewInput() async {
        let viewModel = makeSUT(
            authenticate: { _, _ in .failure(.invalidCredentials) }
        )

        viewModel.username = "test@fail.com"
        viewModel.password = "wrongpass"
        await viewModel.login()
        XCTAssertNotNil(viewModel.errorMessage)

        viewModel.username = "new@input.com"
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: Helpers

    private func makeSUT(
        authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError> = { _, _ in .failure(.invalidCredentials) },
        failedAttemptsStore: FailedLoginAttemptsStore = ThreadSafeFailedLoginAttemptsStoreSpy(),
        maxFailedAttempts: Int = 5,
        blockMessageProvider: LoginBlockMessageProvider = DefaultLoginBlockMessageProvider(),
        file: StaticString = #file,
        line: UInt = #line
    ) -> LoginViewModel {
        let sut = LoginViewModel(
            authenticate: { username, password in
                await authenticate(username, password)
            },
            failedAttemptsStore: failedAttemptsStore,
            maxFailedAttempts: maxFailedAttempts,
            blockMessageProvider: blockMessageProvider
        )
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }

    private class NavigationSpy: LoginNavigation {
        private(set) var recoveryScreenShown = false

        func showRecovery() {
            recoveryScreenShown = true
        }
    }
}
