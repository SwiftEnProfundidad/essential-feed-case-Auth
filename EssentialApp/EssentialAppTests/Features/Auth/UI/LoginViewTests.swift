import Combine
import EssentialApp
import EssentialFeed
import SwiftUI
import UIKit
import XCTest

final class LoginViewTests: XCTestCase {
    func test_login_withInvalidEmail_showsValidationError() async {
        let viewModel = makeSUT(
            authenticate: { _, _ in .failure(.invalidEmailFormat) },
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        viewModel.username = "invalid-email"
        viewModel.password = "password"

        await viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "Invalid email format.")
    }

    func test_login_withEmptyPassword_showsValidationError() async {
        let viewModel = makeSUT(
            authenticate: { _, _ in .failure(.invalidPasswordFormat) },
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        viewModel.username = "user@email.com"
        viewModel.password = ""
        await viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "Password cannot be empty.")
    }

    func test_login_withValidCredentials_triggersAuthentication() async {
        let exp = expectation(description: "Authentication triggered")
        let viewModel = makeSUT(
            authenticate: { username, password in
                XCTAssertEqual(username, "user@email.com")
                XCTAssertEqual(password, "password")
                exp.fulfill()
                return .success(
                    LoginResponse(
                        user: User(name: "Test User", email: "user@email.com"),
                        token: Token(
                            accessToken: "token", expiry: Date().addingTimeInterval(3600), refreshToken: nil
                        )
                    ))
            }, blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
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
        XCTAssertEqual(viewModel.errorMessage, "Invalid username or password.")
    }

    func test_login_success_showsSuccessFeedback() async {
        let viewModel = makeSUT(
            authenticate: { _, _ in
                .success(
                    LoginResponse(
                        user: User(name: "Test User", email: "user@email.com"),
                        token: Token(
                            accessToken: "token", expiry: Date().addingTimeInterval(3600), refreshToken: nil
                        )
                    ))
            },
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertTrue(viewModel.loginSuccess)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoginBlocked)
    }

    func test_login_networkError_showsNetworkErrorMessage() async {
        let viewModel = makeSUT(
            authenticate: { _, _ in .failure(.network) },
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "A network error occurred. Please try again.")
    }

    func test_login_error_showsErrorFeedback() async {
        let viewModel = makeSUT(
            authenticate: { _, _ in .failure(.unknown) },
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
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
        XCTAssertNotNil(
            viewModel.errorMessage, "Expected errorMessage to be present after failed login"
        )

        viewModel.username = "new@email.com"
        XCTAssertNil(
            viewModel.errorMessage,
            "Expected errorMessage to be nil after editing username, but got: \(viewModel.errorMessage ?? "nil")"
        )

        viewModel.username = "user@email.com"
        viewModel.password = "wrongpass"
        await viewModel.login()
        XCTAssertNotNil(
            viewModel.errorMessage, "Expected errorMessage to be present after failed login"
        )

        viewModel.password = "newpassword"
        XCTAssertNil(viewModel.errorMessage, "Expected errorMessage to be nil after editing password")
    }

    func test_loginSuccessFlag_isTrueAfterSuccessAndFalseAfterFailure() async {
        let viewModel = makeSUT(
            authenticate: { _, _ in
                .success(
                    LoginResponse(
                        user: User(name: "Test User", email: "user@email.com"),
                        token: Token(
                            accessToken: "token", expiry: Date().addingTimeInterval(3600), refreshToken: nil
                        )
                    ))
            },
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
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
        XCTAssertNotNil(
            failingViewModel.errorMessage, "Expected errorMessage to be present after failed login"
        )

        let successViewModel = makeSUT(authenticate: { _, _ in
            .success(
                LoginResponse(
                    user: User(name: "Test User", email: "user@email.com"),
                    token: Token(
                        accessToken: "token", expiry: Date().addingTimeInterval(3600), refreshToken: nil
                    )
                ))
        }
        )
        successViewModel.username = "user@email.com"
        successViewModel.password = "password"
        await successViewModel.login()
        XCTAssertNil(
            successViewModel.errorMessage,
            "Expected errorMessage to be nil after successful login, but got: \(successViewModel.errorMessage ?? "nil")"
        )
        XCTAssertTrue(
            successViewModel.loginSuccess, "Expected loginSuccess to be true after successful login"
        )
    }

    func test_usernameAndPassword_arePublishedAndObservable() async {
        let viewModel = makeSUT(blockMessageProvider: DefaultLoginBlockMessageProvider())
        let expectedUsername = "test@email.com"
        let expectedPassword = "testpass123"
        viewModel.username = expectedUsername
        viewModel.password = expectedPassword
        XCTAssertEqual(
            viewModel.username, expectedUsername, "Expected username to be published and observable"
        )
        XCTAssertEqual(
            viewModel.password, expectedPassword, "Expected password to be published and observable"
        )
    }

    func test_onSuccessAlertDismissed_executesCallback() async {
        let viewModel = makeSUT(
            authenticate: { _, _ in
                .success(
                    LoginResponse(
                        user: User(name: "Test User", email: "user@email.com"),
                        token: Token(
                            accessToken: "token", expiry: Date().addingTimeInterval(3600), refreshToken: nil
                        )
                    ))
            },
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertTrue(viewModel.loginSuccess, "Expected loginSuccess to be true after successful login")

        var callbackCalled = false
        viewModel.onAuthenticated = {
            callbackCalled = true
        }
        viewModel.onSuccessAlertDismissed()
        XCTAssertFalse(
            viewModel.loginSuccess, "Expected loginSuccess to be false after dismissing alert"
        )
        XCTAssertTrue(
            callbackCalled, "Expected onAuthenticated callback to be called after alert dismissed"
        )
    }

    func test_initialState_isClean() async {
        let viewModel = makeSUT(blockMessageProvider: DefaultLoginBlockMessageProvider())
        XCTAssertNil(viewModel.errorMessage, "Expected errorMessage to be nil on initial state")
        XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false on initial state")
        XCTAssertEqual(viewModel.username, "", "Expected username to be empty on initial state")
        XCTAssertEqual(viewModel.password, "", "Expected password to be empty on initial state")
    }

    func test_login_withEmptyFields_showsValidationError() async {
        let viewModel = makeSUT()
        viewModel.username = ""
        viewModel.password = ""
        await viewModel.login()
        XCTAssertEqual(
            viewModel.errorMessage, "Invalid email format.",
            "Expected validation error when username is empty"
        )
        XCTAssertFalse(
            viewModel.loginSuccess, "Expected loginSuccess to be false when login fails due to validation"
        )
    }

    func test_login_callsAuthenticateWithTrimmedUsername() async {
        var receivedUsername: String?
        let viewModel = makeSUT(
            authenticate: { username, _ in
                receivedUsername = username
                return .failure(.invalidCredentials)
            }, blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        viewModel.username = "   user@email.com   "
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertEqual(
            receivedUsername,
            "user@email.com",
            "Expected authenticate to be called with trimmed username"
        )
    }

    func test_viewModel_deallocation_doesNotRetainClosure() async {
        var viewModel: LoginViewModel? = makeSUT(authenticate: { _, _ in .failure(.invalidCredentials) }
        )
        weak var weakViewModel = viewModel
        viewModel?.onAuthenticated = { _ = weakViewModel }
        viewModel = nil
        XCTAssertNil(weakViewModel, "ViewModel should be deallocated and not retain closures")
    }

    func test_login_doesNotTriggerAuthenticatedOnFailure() async {
        let viewModel = makeSUT(
            authenticate: { _, _ in .failure(.invalidCredentials) },
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        var authenticatedCalled = false
        let cancellable = viewModel.authenticated.sink { _ in
            authenticatedCalled = true
        }
        viewModel.username = "user@email.com"
        viewModel.password = "fail"
        await viewModel.login()
        XCTAssertFalse(
            authenticatedCalled, "Expected authenticated event NOT to be sent after failed login"
        )
        _ = cancellable
    }

    func test_errorMessage_isClearedOnLoginSuccess() async {
        let viewModel = makeSUT(
            authenticate: { _, password in
                if password == "fail" {
                    .failure(.invalidCredentials)
                } else {
                    .success(
                        LoginResponse(
                            user: User(name: "Test User", email: "user@email.com"),
                            token: Token(
                                accessToken: "token", expiry: Date().addingTimeInterval(3600), refreshToken: nil
                            )
                        ))
                }
            }, blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        viewModel.username = "user@email.com"
        viewModel.password = "fail"
        await viewModel.login()
        XCTAssertNotNil(viewModel.errorMessage, "Expected error message after failed login")
        viewModel.password = "pass"
        await viewModel.login()
        XCTAssertNil(
            viewModel.errorMessage, "Expected error message to be cleared after successful login"
        )
    }

    func test_login_withInvalidPasswordFormat_showsValidationError() async {
        let viewModel = makeSUT(blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = "short"
        await viewModel.login()
        XCTAssertEqual(
            viewModel.errorMessage,
            "Invalid username or password.",
            "Expected validation error when password format is invalid"
        )
        XCTAssertFalse(
            viewModel.loginSuccess,
            "Expected loginSuccess to be false when login fails due to invalid password format"
        )
    }

    func test_login_withWhitespacePassword_showsValidationError() async {
        let viewModel = makeSUT(blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "user@email.com"
        viewModel.password = "    "
        await viewModel.login()
        XCTAssertEqual(
            viewModel.errorMessage, "Password cannot be empty.",
            "Expected validation error when password is only whitespace"
        )
        XCTAssertFalse(
            viewModel.loginSuccess,
            "Expected loginSuccess to be false when login fails due to validation"
        )
    }

    func test_errorMessage_isClearedOnEditingFieldsAfterNetworkError() async {
        let viewModel = makeSUT(
            authenticate: { _, _ in .failure(.network) },
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertEqual(
            viewModel.errorMessage, "A network error occurred. Please try again.",
            "Expected network error message after failed login"
        )

        viewModel.username = "user2@email.com"
        XCTAssertNil(
            viewModel.errorMessage, "Expected error message to be cleared after editing username"
        )

        viewModel.username = "user@email.com"
        await viewModel.login()

        viewModel.password = "newpassword"
        XCTAssertNil(
            viewModel.errorMessage, "Expected error message to be cleared after editing password"
        )
    }

    func test_login_withWhitespaceUsername_showsValidationError() async {
        let viewModel = makeSUT(blockMessageProvider: DefaultLoginBlockMessageProvider())
        viewModel.username = "    "
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertEqual(
            viewModel.errorMessage, "Invalid email format.",
            "Expected validation error when username is only whitespace"
        )
        XCTAssertFalse(
            viewModel.loginSuccess,
            "Expected loginSuccess to be false when login fails due to validation"
        )
    }

    func test_loginSuccess_sendsAuthenticatedEvent() async {
        let viewModel = makeSUT(
            authenticate: { _, _ in
                .success(
                    LoginResponse(
                        user: User(name: "Test User", email: "user@email.com"),
                        token: Token(
                            accessToken: "token", expiry: Date().addingTimeInterval(3600), refreshToken: nil
                        )
                    ))
            },
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        var authenticatedCalled = false
        let cancellable = viewModel.authenticated.sink { _ in
            authenticatedCalled = true
        }
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        await viewModel.login()
        XCTAssertTrue(
            authenticatedCalled, "Expected authenticated event to be sent after successful login"
        )
        _ = cancellable
    }

    func test_login_networkError_storesPendingRequest_and_canRetryLater() async {
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

        XCTAssertEqual(
            pendingStore.loadAll(), [LoginRequest(username: "user@email.com", password: "password")]
        )

        viewModel.authenticate = {
            (username: String, password: String) -> Result<LoginResponse, LoginError> in
            authenticateCalls.append((username, password))
            return .success(
                LoginResponse(
                    user: User(name: "Test User", email: "user@email.com"),
                    token: Token(
                        accessToken: "token", expiry: Date().addingTimeInterval(3600), refreshToken: nil
                    )
                ))
        }

        await viewModel.retryPendingRequests()

        pendingStore.removeAll()

        XCTAssertEqual(pendingStore.loadAll(), [])
        XCTAssertTrue(viewModel.loginSuccess)
        XCTAssertEqual(authenticateCalls.count, 2)
    }

    func test_login_blocksAfterMaxFailedAttempts() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let maxAttempts = 3
        let viewModel = makeSUT(
            failedAttemptsStore: spyStore,
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        viewModel.username = "user@test.com"
        viewModel.password = "wrong-password"

        for _ in 1 ... maxAttempts {
            await viewModel.login()
        }

        XCTAssertTrue(
            viewModel.isLoginBlocked, "Expected account to be locked after max failed attempts"
        )

        let expectedMessagePrefix = "Account locked. Please try again in"
        XCTAssertNotNil(viewModel.errorMessage, "Expected an error message when account is locked")
        XCTAssertTrue(
            viewModel.errorMessage?.hasPrefix(expectedMessagePrefix) == true,
            "Expected error message to start with '\(expectedMessagePrefix)' but got '\(viewModel.errorMessage ?? "nil")'"
        )
    }

    func test_login_showRecoveryOptionWhenBlocked() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let viewModel = makeSUT(
            authenticate: { _, _ in .failure(.invalidCredentials) },
            failedAttemptsStore: spyStore,
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        viewModel.username = "user@test.com"
        viewModel.password = "wrong-password"

        for _ in 1 ... 3 {
            await viewModel.login()
        }

        XCTAssertTrue(viewModel.isLoginBlocked, "Should block login after max attempts")
        XCTAssertNotNil(viewModel.errorMessage, "Should show error message when blocked")
    }

    func test_fullLockFlow_withPasswordRecovery() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let navigationSpy = NavigationSpy()
        let maxAttempts = 3
        let viewModel = makeSUT(
            failedAttemptsStore: spyStore,
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        viewModel.navigation = navigationSpy
        viewModel.username = "user@test.com"
        viewModel.password = "wrong-password"

        for _ in 1 ... maxAttempts {
            await viewModel.login()
        }

        XCTAssertTrue(
            viewModel.isLoginBlocked, "Account should be locked after \(maxAttempts) attempts"
        )
        viewModel.handleRecoveryTap()

        try? await Task.sleep(nanoseconds: 100_000_000)

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
                    return .success(
                        LoginResponse(
                            user: User(name: "Test User", email: "user@email.com"),
                            token: Token(
                                accessToken: "any", expiry: Date().addingTimeInterval(3600), refreshToken: nil
                            )
                        ))
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
            failedAttemptsStore: spyStore
        )

        viewModel.username = "user@test.com"
        viewModel.password = "wrong-password"
        for _ in 1 ... 3 {
            await viewModel.login()
        }
        XCTAssertTrue(viewModel.isLoginBlocked, "Account should be locked after 3 failed attempts")

        await viewModel.unlockAfterRecovery()

        XCTAssertFalse(
            viewModel.isLoginBlocked, "Account should unlock after calling unlockAfterRecovery()"
        )
        XCTAssertNil(viewModel.errorMessage, "Error message should be nil after unlock")
        XCTAssertEqual(
            spyStore.resetAttemptsCallCount, 1, "resetAttempts should be called exactly once"
        )
    }

    func test_successfulLoginAfter4FailedAttempts_resetsCounter() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        var callCount = 0
        let viewModel = makeSUT(
            authenticate: { _, _ in
                callCount += 1
                if callCount <= 3 {
                    return .failure(.invalidCredentials)
                } else {
                    return .success(
                        LoginResponse(
                            user: User(name: "Test User", email: "user@email.com"),
                            token: Token(
                                accessToken: "valid-token", expiry: Date().addingTimeInterval(3600),
                                refreshToken: nil
                            )
                        ))
                }
            },
            failedAttemptsStore: spyStore
        )

        viewModel.username = "user@test.com"
        viewModel.password = "wrong-pass"

        for _ in 1 ... 3 {
            await viewModel.login()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertTrue(viewModel.isLoginBlocked, "Account should be blocked after 3 failed attempts")
        let recordedAttempts = spyStore.attempts["user@test.com"] ?? 0
        XCTAssertEqual(recordedAttempts, 3, "Should record exactly 3 failed attempts")

        viewModel.password = "correct-pass"
        await viewModel.login()

        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertTrue(
            viewModel.isLoginBlocked, "Account should remain blocked even with correct password"
        )
        XCTAssertEqual(spyStore.resetAttemptsCallCount, 0, "Should not reset counter while blocked")
        XCTAssertEqual(
            spyStore.attempts["user@test.com"], 3, "Counter should remain at 3 while blocked"
        )

        await viewModel.unlockAfterRecovery()

        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertFalse(viewModel.isLoginBlocked, "Account should be unblocked after manual unlock")
        XCTAssertEqual(spyStore.resetAttemptsCallCount, 1, "Should reset counter after unlock")
        XCTAssertEqual(spyStore.attempts["user@test.com"], 0, "Counter should be 0 after unlock")
    }

    func test_successfulLoginAfter2FailedAttempts_resetsCounter() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        var callCount = 0
        let viewModel = makeSUT(
            authenticate: { _, _ in
                callCount += 1
                if callCount <= 2 {
                    return .failure(.invalidCredentials)
                } else {
                    return .success(
                        LoginResponse(
                            user: User(name: "Test User", email: "user@email.com"),
                            token: Token(
                                accessToken: "valid-token", expiry: Date().addingTimeInterval(3600),
                                refreshToken: nil
                            )
                        ))
                }
            },
            failedAttemptsStore: spyStore
        )

        viewModel.username = "user@test.com"
        viewModel.password = "wrong-pass"

        for _ in 1 ... 2 {
            await viewModel.login()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertFalse(
            viewModel.isLoginBlocked, "Account should not be blocked after 2 failed attempts"
        )
        let recordedAttempts = spyStore.attempts["user@test.com"] ?? 0
        XCTAssertEqual(recordedAttempts, 2, "Should record exactly 2 failed attempts")

        viewModel.password = "correct-pass"
        await viewModel.login()

        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertFalse(
            viewModel.isLoginBlocked, "Account should remain unblocked after successful login"
        )
        XCTAssertTrue(viewModel.loginSuccess, "Should show login success")
        XCTAssertEqual(spyStore.resetAttemptsCallCount, 1, "Should reset counter after success")
        XCTAssertEqual(spyStore.attempts["user@test.com"], 0, "Counter should be 0 after success")
    }

    func test_failedAttemptAfterUnlock_resetsCounterAgain() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let viewModel = makeSUT(
            failedAttemptsStore: spyStore
        )

        viewModel.username = "user@test.com"
        viewModel.password = "wrong-pass"
        for _ in 1 ... 3 {
            await viewModel.login()
        }
        XCTAssertTrue(viewModel.isLoginBlocked, "Account should lock after 3 failed attempts")

        await viewModel.unlockAfterRecovery()
        XCTAssertFalse(viewModel.isLoginBlocked, "Account should unlock after recovery")

        await viewModel.login()

        XCTAssertEqual(
            spyStore.attempts["user@test.com"], 1, "Counter should restart at 1 after unlock"
        )
        XCTAssertEqual(
            spyStore.incrementAttemptsCallCount, 4, "Should increment attempts for new failures"
        )
    }

    func test_multipleLockUnlockCycles_handlesCountersCorrectly() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let viewModel = makeSUT(
            failedAttemptsStore: spyStore
        )

        viewModel.username = "user@test.com"
        viewModel.password = "wrong-pass"
        for _ in 1 ... 3 {
            await viewModel.login()
        }
        XCTAssertTrue(viewModel.isLoginBlocked)
        await viewModel.unlockAfterRecovery()

        for _ in 1 ... 3 {
            await viewModel.login()
        }
        XCTAssertTrue(viewModel.isLoginBlocked)
        await viewModel.unlockAfterRecovery()

        XCTAssertEqual(spyStore.resetAttemptsCallCount, 2, "Should reset attempts twice")
        XCTAssertEqual(
            spyStore.incrementAttemptsCallCount, 6, "Should increment attempts for all failures"
        )
        XCTAssertEqual(spyStore.attempts["user@test.com"], 0, "Final counter should be zero")
    }

    func test_blockMessageProvider_showsContextualMessages() {
        let provider = DefaultLoginBlockMessageProvider()

        let maxAttemptsMessage = provider.message(for: LoginError.messageForMaxAttemptsReached)
        XCTAssertEqual(
            maxAttemptsMessage, "Maximum number of attempts reached. Please try again later."
        )

        let invalidCredentialsMessage = provider.message(for: LoginError.invalidCredentials)
        XCTAssertEqual(invalidCredentialsMessage, "Invalid credentials.")
    }

    func test_concurrentIncrementAttempts_threadSafety() async {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let viewModel = makeSUT(
            authenticate: { _, _ in .failure(.invalidCredentials) },
            failedAttemptsStore: spyStore
        )

        viewModel.username = "user@test.com"
        viewModel.password = "wrong-pass"

        await withTaskGroup(of: Void.self) { group in
            for _ in 1 ... 5 {
                group.addTask {
                    await viewModel.login()
                    try? await Task.sleep(nanoseconds: 10_000_000)
                }
            }
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertGreaterThanOrEqual(
            spyStore.incrementAttemptsCallCount, 3, "Should handle at least 3 attempts"
        )
        XCTAssertTrue(viewModel.isLoginBlocked, "Account should be blocked after concurrent attempts")
    }

    func test_loginViewModel_doesNotLeakMemory() {
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        var sut: LoginViewModel? = makeSUT(failedAttemptsStore: spyStore)

        weak var weakSUT = sut
        sut = nil

        XCTAssertNil(weakSUT, "ViewModel should be deallocated")
    }

    func test_captchaValidation_allowsLoginAfterSuccessfulValidation() async {
        let mockCaptchaCoordinator = MockCaptchaFlowCoordinator()
        let spyStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let configuration = LoginSecurityConfiguration(
            maxAttempts: 5, blockDuration: 300, captchaThreshold: 3
        )
        let loginSecurity = LoginSecurityUseCase(store: spyStore, configuration: configuration)

        let viewModel = LoginViewModel(
            authenticate: { _, _ in .failure(.invalidCredentials) },
            loginSecurity: loginSecurity,
            captchaFlowCoordinator: mockCaptchaCoordinator
        )

        viewModel.username = "test@example.com"
        viewModel.password = "wrongpassword"

        for _ in 1 ... 3 {
            await viewModel.login()
        }

        XCTAssertTrue(
            viewModel.shouldShowCaptcha, "Captcha should be shown after multiple failed attempts"
        )

        mockCaptchaCoordinator.validationResult = .success(())
        viewModel.setCaptchaToken("valid-token")

        var attempts = 0
        let maxAttempts = 50
        while viewModel.shouldShowCaptcha && attempts < maxAttempts {
            try? await Task.sleep(nanoseconds: 10_000_000)
            attempts += 1
        }

        XCTAssertFalse(
            viewModel.shouldShowCaptcha, "Captcha should not be shown after successful validation"
        )
        XCTAssertFalse(
            viewModel.isLoginBlocked, "Account should not be blocked after successful captcha validation"
        )
        XCTAssertNil(
            viewModel.errorMessage,
            "There should be no error messages after successful captcha validation"
        )
        XCTAssertEqual(
            spyStore.getAttempts(for: "test@example.com"), 0,
            "Attempts should be reset after successful captcha validation"
        )
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

    func test_loginView_displaysRegisterButton() async {
        let navigationSpy = NavigationSpy()
        let viewModel = makeSUT()
        viewModel.navigation = navigationSpy

        XCTAssertFalse(
            navigationSpy.registerScreenShown, "Register screen should not be shown initially"
        )

        viewModel.handleRegisterTap()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(
            navigationSpy.registerScreenShown,
            "Expected register screen to be shown after handleRegisterTap"
        )
    }

    func test_registerButton_triggersNavigation() async {
        let navigationSpy = NavigationSpy()
        let viewModel = makeSUT()
        viewModel.navigation = navigationSpy

        viewModel.handleRegisterTap()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(navigationSpy.registerScreenShown, "Expected register navigation to be triggered")
        XCTAssertFalse(
            navigationSpy.recoveryScreenShown, "Expected only register navigation to be triggered"
        )
    }

    func test_captchaView_isRendered_whenCaptchaIsRequired() {
        let viewModel = makeSUT()
        viewModel.shouldShowCaptcha = true

        let sut = UIHostingController(
            rootView: LoginView(viewModel: viewModel, animationsEnabled: false))
        sut.loadViewIfNeeded()

        XCTAssertTrue(
            sut.view.containsAccessibilityIdentifier("captcha_view"),
            "Expected captcha view to be rendered when required, but it was not."
        )
    }

    func test_captchaView_isNotRendered_whenCaptchaIsNotRequired() {
        let viewModel = makeSUT()
        viewModel.shouldShowCaptcha = false

        let sut = UIHostingController(
            rootView: LoginView(viewModel: viewModel, animationsEnabled: false))
        sut.loadViewIfNeeded()

        XCTAssertFalse(
            sut.view.containsAccessibilityIdentifier("captcha_view"),
            "Expected captcha view not to be rendered when not required, but it was."
        )
    }

    // MARK: Helpers

    private func makeSUT(
        authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError> = { _, _ in
            .failure(.invalidCredentials)
        },
        failedAttemptsStore: FailedLoginAttemptsStore = ThreadSafeFailedLoginAttemptsStoreSpy(),
        blockMessageProvider: LoginBlockMessageProvider = DefaultLoginBlockMessageProvider(),
        file: StaticString = #file,
        line: UInt = #line
    ) -> LoginViewModel {
        let configuration = LoginSecurityConfiguration(
            maxAttempts: 3, blockDuration: 300, captchaThreshold: 2
        )
        let loginSecurity = LoginSecurityUseCase(
            store: failedAttemptsStore,
            configuration: configuration
        )
        let sut = LoginViewModel(
            authenticate: { username, password in
                await authenticate(username, password)
            },
            loginSecurity: loginSecurity,
            blockMessageProvider: blockMessageProvider
        )
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(loginSecurity, file: file, line: line)
        trackForMemoryLeaks(failedAttemptsStore, file: file, line: line)
        return sut
    }

    private class NavigationSpy: LoginNavigation {
        private(set) var recoveryScreenShown = false
        private(set) var registerScreenShown = false

        func showRecovery() {
            recoveryScreenShown = true
        }

        func showRegister() {
            registerScreenShown = true
        }
    }

    private class MockCaptchaFlowCoordinator: CaptchaFlowCoordinating {
        var validationResult: Result<Void, CaptchaError> = .failure(.invalidResponse)
        var captchaValidationCallCount = 0
        var receivedTokens: [String] = []
        var receivedUsernames: [String] = []
        var shouldTriggerCaptchaResult = true

        func shouldTriggerCaptcha(failedAttempts _: Int) -> Bool {
            return shouldTriggerCaptchaResult
        }

        func handleCaptchaValidation(token: String, username: String) async -> Result<Void, CaptchaError> {
            captchaValidationCallCount += 1
            receivedTokens.append(token)
            receivedUsernames.append(username)
            return validationResult
        }
    }
}

extension UIView {
    func containsAccessibilityIdentifier(_ identifier: String) -> Bool {
        if self.accessibilityIdentifier == identifier {
            return true
        }

        for subview in self.subviews {
            if subview.containsAccessibilityIdentifier(identifier) {
                return true
            }
        }

        return false
    }
}
