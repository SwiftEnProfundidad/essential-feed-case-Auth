import EssentialFeed
import Foundation
import XCTest

final class UserLoginUseCaseTests: XCTestCase {
    func test_login_fails_withEmptyEmail_andDoesNotSendRequest() async {
        let (sut, api, _, failureObserver, _, _, _) = makeSUT()
        let credentials = LoginCredentials(email: "", password: "ValidPassword123")
        let result = await sut.login(with: credentials)
        switch result {
        case let .failure(error):
            guard let loginError = error as? LoginError else {
                XCTFail("Expected LoginError, got \(error)")
                return
            }
            XCTAssertEqual(loginError, .invalidEmailFormat, "Should return invalid email format error for empty email")
            XCTAssertFalse(api.wasCalled, "API should NOT be called when email is empty")
            XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on validation error")
        case .success:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_fails_withWhitespaceOnlyEmail_andDoesNotSendRequest() async {
        let (sut, api, _, failureObserver, _, _, _) = makeSUT()
        let credentials = LoginCredentials(email: "    ", password: "ValidPassword123")
        let result = await sut.login(with: credentials)
        switch result {
        case let .failure(error):
            guard let loginError = error as? LoginError else {
                XCTFail("Expected LoginError, got \(error)")
                return
            }
            XCTAssertEqual(loginError, .invalidEmailFormat, "Should return invalid email format error for whitespace-only email")
            XCTAssertFalse(api.wasCalled, "API should NOT be called when email is whitespace-only")
            XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on validation error")
        case .success:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_fails_withWhitespaceOnlyPassword_andDoesNotSendRequest() async {
        let (sut, api, _, failureObserver, _, _, _) = makeSUT()
        let credentials = LoginCredentials(email: "user@example.com", password: "     ")
        let result = await sut.login(with: credentials)
        switch result {
        case let .failure(error):
            guard let loginError = error as? LoginError else {
                XCTFail("Expected LoginError, got \(error)")
                return
            }
            XCTAssertEqual(loginError, .invalidPasswordFormat, "Should return invalid password format error for whitespace-only password")
            XCTAssertFalse(api.wasCalled, "API should NOT be called when password is whitespace-only")
            XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on validation error")
        case .success:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_fails_withShortPassword_andDoesNotSendRequest() async {
        let (sut, api, _, failureObserver, _, _, _) = makeSUT()
        let credentials = LoginCredentials(email: "user@example.com", password: "12345")
        let result = await sut.login(with: credentials)
        switch result {
        case let .failure(error):
            guard let loginError = error as? LoginError else {
                XCTFail("Expected LoginError, got \(error)")
                return
            }
            XCTAssertEqual(loginError, .invalidPasswordFormat, "Should return invalid password format error for short password")
            XCTAssertFalse(api.wasCalled, "API should NOT be called when password is too short")
            XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on validation error")
        case .success:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_fails_withEmptyEmailAndPassword_andDoesNotSendRequest() async {
        let (sut, api, _, failureObserver, _, _, _) = makeSUT()
        let credentials = LoginCredentials(email: "", password: "")
        let result = await sut.login(with: credentials)
        switch result {
        case let .failure(error):
            if let loginError = error as? LoginError {
                XCTAssertEqual(loginError, .invalidEmailFormat, "Should return invalid email format error when both fields are empty (email checked first)")
            } else {
                XCTFail("Expected LoginError.invalidEmailFormat, got \(error)")
            }
            XCTAssertFalse(api.wasCalled, "API should NOT be called when both fields are empty")
            XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on validation error")
        case .success:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_fails_withInvalidEmailFormat_andDoesNotSendRequest() async {
        let (sut, api, _, failureObserver, _, _, _) = makeSUT()
        let invalidEmail = "usuario_invalido"
        let credentials = LoginCredentials(email: invalidEmail, password: "ValidPassword123")

        let result = await sut.login(with: credentials)

        switch result {
        case let .failure(error):
            if let loginError = error as? LoginError {
                XCTAssertEqual(loginError, .invalidEmailFormat, "Should return invalid email format error")
            } else {
                XCTFail("Expected LoginError.invalidEmailFormat, got \(error)")
            }
            XCTAssertFalse(api.wasCalled, "API should NOT be called when email format is invalid")
            XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on validation error")
        case .success:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_fails_withInvalidPassword_andDoesNotSendRequest() async {
        let (sut, api, _, failureObserver, _, _, _) = makeSUT()
        let invalidPassword = ""
        let credentials = LoginCredentials(email: "user@example.com", password: invalidPassword)

        let result = await sut.login(with: credentials)

        switch result {
        case let .failure(error):
            if let loginError = error as? LoginError {
                XCTAssertEqual(loginError, .invalidPasswordFormat, "Should return invalid password format error")
            } else {
                XCTFail("Expected LoginError.invalidPasswordFormat, got \(error)")
            }
            XCTAssertFalse(api.wasCalled, "API should NOT be called when password is invalid")
            XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on validation error")
        case .success:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_fails_onInvalidCredentials() async throws {
        let (sut, api, _, failureObserver, _, _, _) = makeSUT()
        let credentials = LoginCredentials(email: "user@example.com", password: "wrongpass")

        api.stubbedResult = Result<LoginResponse, LoginError>.failure(.invalidCredentials)

        let result = await sut.login(with: credentials)
        switch result {
        case .success:
            XCTFail("Expected failure, got success")
        case let .failure(error):
            if let loginError = error as? LoginError {
                XCTAssertEqual(loginError, .invalidCredentials, "Should return invalid credentials error on failure")
            } else {
                XCTFail("Expected LoginError.invalidCredentials, got \(error)")
            }
            XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on failed login")
        }
    }

    func test_login_succeeds_storesToken_andNotifiesObserver() async throws {
        let (sut, api, successObserver, _, tokenStorage, _, _) = makeSUT()
        let credentials = LoginCredentials(email: "user@example.com", password: "password123")

        let expectedTokenValue = "jwt-token-123"
        let expectedTokenExpiry = Date().addingTimeInterval(3600)
        let expectedToken = Token(value: expectedTokenValue, expiry: expectedTokenExpiry)
        let apiResponse = LoginResponse(token: expectedTokenValue)

        api.stubbedResult = .success(apiResponse)

        let result = await sut.login(with: credentials)
        switch result {
        case let .success(response):
            XCTAssertEqual(response.token, expectedTokenValue, "Returned token value should match expected token value")
            XCTAssertTrue(successObserver.didNotifySuccess, "Success observer should be notified on successful login")
            XCTAssertEqual(tokenStorage.messages.count, 1, "Expected 1 message (save) in TokenStorageSpy")
            guard tokenStorage.messages.count == 1 else { return }
            switch tokenStorage.messages[0] {
            case let .save(savedToken):
                XCTAssertEqual(savedToken.value, expectedToken.value, "Saved token value mismatch")
                XCTAssertTrue(abs(savedToken.expiry.timeIntervalSince(expectedToken.expiry)) < 1.0, "Saved token expiry mismatch")
            default:
                XCTFail("Expected .save message, got \(tokenStorage.messages[0])")
            }

        case let .failure(error):
            XCTFail("Expected success, got failure: \(error)")
        }
    }

    func test_login_succeedsApiCall_butFailsToStoreToken_returnsError() async throws {
        let (sut, api, successObserver, _, tokenStorage, _, _) = makeSUT()
        let credentials = LoginCredentials(email: "user@example.com", password: "password123")

        let expectedTokenValue = "jwt-token-for-fail-case"
        let apiResponse = LoginResponse(token: expectedTokenValue)
        api.stubbedResult = .success(apiResponse)

        let storageError = NSError(domain: "TokenStorageError", code: 1)
        tokenStorage.saveTokenError = storageError

        let result = await sut.login(with: credentials)

        switch result {
        case .success:
            XCTFail("Expected failure due to token storage error, got success")
        case let .failure(error):
            if let loginError = error as? LoginError {
                XCTAssertEqual(loginError, .tokenStorageFailed, "Expected token storage error")
            } else {
                XCTFail("Expected LoginError.tokenStorageFailed, got \(error)")
            }
        }

        XCTAssertFalse(successObserver.didNotifySuccess, "Success observer should NOT be notified if token storage fails")
        XCTAssertEqual(tokenStorage.messages.count, 1, "Expected TokenStorage save attempt")
    }

    func test_login_incrementsFailedAttempts_onInvalidCredentialsError() async {
        let (sut, api, _, _, _, _, failedAttemptsStore) = makeSUT()
        let credentials = LoginCredentials(email: "user@example.com", password: "wrongpass")

        api.stubbedResult = Result<LoginResponse, LoginError>.failure(.invalidCredentials)

        _ = await sut.login(with: credentials)

        XCTAssertTrue(failedAttemptsStore.messages.contains(.incrementAttempts("user@example.com")), "Should increment attempts for the correct username")
        if let last = failedAttemptsStore.messages.last(where: {
            if case .incrementAttempts = $0 { true } else { false }
        }) {
            XCTAssertEqual(last, .incrementAttempts("user@example.com"), "Should increment attempts for the correct username")
        } else {
            XCTFail("No incrementAttempts message found")
        }
    }

    func test_login_doesNotIncrementFailedAttempts_onFormatErrors() async {
        let (sut, _, _, _, _, _, failedAttemptsStore) = makeSUT()
        let credentials = LoginCredentials(email: "invalid", password: "password123")

        _ = await sut.login(with: credentials)

        XCTAssertEqual(failedAttemptsStore.messages.count, 0, "Should not increment failed attempts on format errors")
    }

    func test_login_resetsFailedAttempts_onSuccessfulLogin() async {
        let (sut, api, _, _, _, _, failedAttemptsStore) = makeSUT()
        let credentials = LoginCredentials(email: "user@example.com", password: "password123")

        let expectedTokenValue = "jwt-token-123"
        let apiResponse = LoginResponse(token: expectedTokenValue)
        api.stubbedResult = .success(apiResponse)

        _ = await sut.login(with: credentials)

        XCTAssertTrue(failedAttemptsStore.messages.contains(.resetAttempts("user@example.com")), "Should reset attempts for the correct username")
        if let last = failedAttemptsStore.messages.last(where: {
            if case .resetAttempts = $0 { true } else { false }
        }) {
            XCTAssertEqual(last, .resetAttempts("user@example.com"), "Should reset attempts for the correct username")
        } else {
            XCTFail("No resetAttempts message found")
        }
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #file, line: UInt = #line
    ) -> (
        sut: UserLoginUseCase,
        api: AuthAPISpy,
        successObserver: LoginSuccessObserverSpy,
        failureObserver: LoginFailureObserverSpy,
        tokenStorage: TokenStorageSpy,
        offlineStore: OfflineLoginStoreSpy,
        failedAttemptsStore: FailedLoginAttemptsStoreSpy
    ) {
        let api = AuthAPISpy()
        let successObserver = LoginSuccessObserverSpy()
        let failureObserver = LoginFailureObserverSpy()
        let tokenStorage = TokenStorageSpy()
        let offlineStore = OfflineLoginStoreSpy()
        let failedAttemptsStore = FailedLoginAttemptsStoreSpy()

        let sut = UserLoginUseCase(
            api: api,
            tokenStorage: tokenStorage,
            offlineStore: offlineStore,
            failedAttemptsStore: failedAttemptsStore,
            successObserver: successObserver,
            failureObserver: failureObserver
        )

        trackForMemoryLeaks(api, file: file, line: line)
        trackForMemoryLeaks(successObserver, file: file, line: line)
        trackForMemoryLeaks(failureObserver, file: file, line: line)
        trackForMemoryLeaks(tokenStorage, file: file, line: line)
        trackForMemoryLeaks(offlineStore, file: file, line: line)
        trackForMemoryLeaks(failedAttemptsStore, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)

        return (sut, api, successObserver, failureObserver, tokenStorage, offlineStore, failedAttemptsStore)
    }
}

// MARK: - Spies

public final class OfflineLoginStoreSpy: OfflineLoginStore {
    enum Message: Equatable {
        case save(LoginCredentials)
    }

    private(set) var messages = [Message]()
    var saveError: Error?

    public func save(credentials: LoginCredentials) async throws {
        if let error = saveError {
            throw error
        }
        messages.append(.save(credentials))
    }
}

final class LoginSuccessObserverSpy: LoginSuccessObserver {
    var didNotifySuccess = false
    func didLoginSuccessfully(response _: LoginResponse) {
        didNotifySuccess = true
    }
}

final class LoginFailureObserverSpy: LoginFailureObserver {
    var didNotifyFailure = false
    func didFailLogin(error _: Error) {
        didNotifyFailure = true
    }
}
