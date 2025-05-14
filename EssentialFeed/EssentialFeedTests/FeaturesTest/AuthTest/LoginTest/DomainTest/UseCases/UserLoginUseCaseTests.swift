import EssentialFeed
import Foundation
import XCTest

final class UserLoginUseCaseTests: XCTestCase {
    func test_login_fails_withInvalidPassword_andDoesNotSendRequest() async {
        let (sut, api, _, notifier, flowHandler) = makeSUT()
        let invalidPassword = ""
        let credentials = LoginCredentials(email: "user@example.com", password: invalidPassword)

        let result = await sut.login(with: credentials)

        switch result {
        case let .failure(error):
            if let loginError = error as? LoginError {
                XCTAssertEqual(
                    loginError, .invalidPasswordFormat, "Should return invalid password format error"
                )
            } else {
                XCTFail("Expected LoginError.invalidPasswordFormat, got \(error)")
            }

            XCTAssertFalse(api.wasCalled, "API should NOT be called when password is invalid")
            XCTAssertEqual(notifier.notifiedFailures.count, 1, "Notifier should be notified on validation error")
            XCTAssertEqual(flowHandler.handledResults.count, 1, "FlowHandler should be called on validation error")

        case .success:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_fails_onInvalidCredentials() async throws {
        let (sut, api, _, _, flowHandler) = makeSUT()
        let credentials = LoginCredentials(email: "user@example.com", password: "wrongpass")

        api.stubbedResult = Result<LoginResponse, LoginError>.failure(.invalidCredentials)

        let result = await sut.login(with: credentials)

        switch result {
        case .success:
            XCTFail("Expected failure, got success")
        case let .failure(error):
            if let loginError = error as? LoginError {
                XCTAssertEqual(
                    loginError, .invalidCredentials, "Should return invalid credentials error on failure"
                )
            } else {
                XCTFail("Expected LoginError.invalidCredentials, got \(error)")
            }
            XCTAssertEqual(
                flowHandler.handledResults.count, 1, "FlowHandler should be called on failed login"
            )
        }
    }

    func test_login_succeeds_storesToken_andNotifiesObserver() async throws {
        let (sut, api, persistence, notifier, flowHandler) = makeSUT()
        let credentials = LoginCredentials(email: "user@example.com", password: "password123")
        let expectedTokenValue = "token123"
        let apiResponse = LoginResponse(token: expectedTokenValue)
        api.stubbedResult = .success(apiResponse)

        let result = await sut.login(with: credentials)
        switch result {
        case let .success(response):
            XCTAssertEqual(response.token, expectedTokenValue, "Returned token value should match expected token value")
            XCTAssertEqual(persistence.savedTokens.count, 1, "Token should be saved on successful login")
            XCTAssertEqual(persistence.savedTokens.first?.value, expectedTokenValue, "Saved token should match expected token value")
            XCTAssertEqual(notifier.notifiedSuccesses.count, 1, "Notifier should be notified on successful login")
            XCTAssertEqual(flowHandler.handledResults.count, 1, "FlowHandler should be called on successful login")
        case let .failure(error):
            XCTFail("Expected success, got failure: \(error)")
        }
    }

    func test_login_succeedsApiCall_butFailsToStoreToken_returnsError() async throws {
        let (sut, api, persistence, notifier, flowHandler) = makeSUT()
        let credentials = LoginCredentials(email: "user@example.com", password: "password123")
        let expectedTokenValue = "token123"
        let apiResponse = LoginResponse(token: expectedTokenValue)
        api.stubbedResult = .success(apiResponse)
        persistence.saveTokenError = LoginError.tokenStorageFailed

        let result = await sut.login(with: credentials)
        switch result {
        case .success:
            XCTFail("Expected failure, got success")
        case let .failure(error):
            XCTAssertEqual(error as? LoginError, .tokenStorageFailed, "Should return token storage error")
            XCTAssertEqual(notifier.notifiedSuccesses.count, 0, "Notifier should NOT be notified if token storage fails")
            XCTAssertEqual(persistence.savedTokens.count, 0, "Token should not be saved if storage fails")
            XCTAssertEqual(flowHandler.handledResults.count, 1, "FlowHandler should be called on failed token storage")
        }
    }

    func test_login_incrementsFailedAttempts_onInvalidCredentialsError() async {
        let (sut, api, _, _, flowHandler) = makeSUT()
        let credentials = LoginCredentials(email: "user@example.com", password: "wrongpass")
        api.stubbedResult = Result<LoginResponse, LoginError>.failure(.invalidCredentials)
        _ = await sut.login(with: credentials)

        // Verifica que el flowHandler fue llamado con el error correcto y las credenciales correctas
        let wasIncremented = flowHandler.handledResults.contains { result, creds in
            if case let .failure(error) = result,
               let loginError = error as? LoginError,
               loginError == .invalidCredentials,
               creds.email == credentials.email
            {
                return true
            }
            return false
        }
        XCTAssertTrue(wasIncremented, "FlowHandler should be called with invalid credentials error for the correct user")
    }

    func test_login_doesNotIncrementFailedAttempts_onFormatErrors() async {
        let (sut, _, _, _, flowHandler) = makeSUT()
        let credentials = LoginCredentials(email: "invalid", password: "password123")
        _ = await sut.login(with: credentials)

        let wasCalledForFormatError = flowHandler.handledResults.contains { result, _ in
            if case let .failure(error) = result,
               let loginError = error as? LoginError,
               loginError == .invalidEmailFormat
            {
                return true
            }
            return false
        }
        XCTAssertTrue(wasCalledForFormatError, "FlowHandler should be called for format errors")
    }

    func test_login_resetsFailedAttempts_onSuccessfulLogin() async {
        let (sut, api, _, _, flowHandler) = makeSUT()
        let credentials = LoginCredentials(email: "user@example.com", password: "password123")
        let expectedTokenValue = "jwt-token-123"
        let apiResponse = LoginResponse(token: expectedTokenValue)
        api.stubbedResult = .success(apiResponse)
        _ = await sut.login(with: credentials)

        let wasReset = flowHandler.handledResults.contains { result, creds in
            if case .success = result, creds.email == credentials.email {
                return true
            }
            return false
        }
        XCTAssertTrue(wasReset, "FlowHandler should be called with success for the correct user")
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #file, line: UInt = #line
    ) -> (
        sut: UserLoginUseCase,
        api: AuthAPISpy,
        persistence: LoginPersistenceSpy,
        notifier: LoginEventNotifierSpy,
        flowHandler: LoginFlowHandlerSpy
    ) {
        let api = AuthAPISpy()
        let persistence = LoginPersistenceSpy()
        let notifier = LoginEventNotifierSpy()
        let flowHandler = LoginFlowHandlerSpy()
        let sut = UserLoginUseCase(
            api: api,
            persistence: persistence,
            notifier: notifier,
            flowHandler: flowHandler
        )
        trackForMemoryLeaks(api, file: file, line: line)
        trackForMemoryLeaks(persistence, file: file, line: line)
        trackForMemoryLeaks(notifier, file: file, line: line)
        trackForMemoryLeaks(flowHandler, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, api, persistence, notifier, flowHandler)
    }
}
