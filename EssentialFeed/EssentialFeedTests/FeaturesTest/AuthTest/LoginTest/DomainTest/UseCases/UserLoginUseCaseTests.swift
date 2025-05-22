import EssentialFeed
import Foundation
import XCTest

final class UserLoginUseCaseTests: XCTestCase {
    func test_login_fails_withInvalidPassword_andDoesNotSendRequest() async {
        let (sut, api, _, notifier, flowHandler, _) = makeSUT()
        let invalidPassword = ""
        let credentials = LoginCredentials(email: "user@example.com", password: invalidPassword)

        let result = await sut.login(with: credentials)

        switch result {
        case let .failure(error):
            XCTAssertEqual(error, LoginError.invalidPasswordFormat, "Should return invalid password format error")
            XCTAssertFalse(api.wasCalled, "API should NOT be called when password is invalid")

            XCTAssertFalse(api.wasCalled, "API should NOT be called when password is invalid")
            XCTAssertEqual(notifier.notifiedFailures.count, 1, "Notifier should be notified on validation error")
            XCTAssertEqual(flowHandler.handledResults.count, 1, "FlowHandler should be called on validation error")

        case .success:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_fails_onInvalidCredentials() async throws {
        let email = Self.email(for: #function)
        let (sut, api, _, _, flowHandler, userDefaults) = makeSUT()
        clearUserDefaults(for: email, userDefaults: userDefaults)
        let credentials = LoginCredentials(email: email, password: Self.invalidPassword)

        api.stubbedResult = Result<LoginResponse, LoginError>.failure(.invalidCredentials)

        let result = await sut.login(with: credentials)

        switch result {
        case .success:
            XCTFail("Expected failure, got success")
        case let .failure(error):
            if error == .invalidCredentials {
                XCTAssertEqual(error, LoginError.invalidCredentials, "Should return invalid credentials error on failure")
            } else {
                XCTFail("Expected LoginError.invalidCredentials, got \(error)")
            }
            XCTAssertEqual(flowHandler.handledResults.count, 1, "FlowHandler should be called on failed login")
        }
    }

    func test_login_succeeds_storesToken_andNotifiesObserver() async throws {
        let email = Self.email(for: #function)
        let (sut, api, persistence, notifier, flowHandler, userDefaults) = makeSUT()
        clearUserDefaults(for: email, userDefaults: userDefaults)
        let credentials = LoginCredentials(email: email, password: Self.validPassword)
        let expectedTokenValue = Self.anotherValidToken
        let apiResponse = LoginResponse(token: expectedTokenValue)
        api.stubbedResult = .success(apiResponse)

        let result = await sut.login(with: credentials)
        switch result {
        case let .success(response):
            XCTAssertEqual(response.token, expectedTokenValue, "Returned token value should match expected token value")
            XCTAssertEqual(persistence.savedTokens.count, 1, "Token should be saved on successful login")
            XCTAssertEqual(persistence.savedTokens.first?.accessToken, expectedTokenValue, "Saved token should match expected token value")
            XCTAssertEqual(notifier.notifiedSuccesses.count, 1, "Notifier should be notified on successful login")
            XCTAssertEqual(flowHandler.handledResults.count, 1, "FlowHandler should be called on successful login")
        case let .failure(error):
            XCTFail("Expected success, got failure: \(error)")
        }
    }

    func test_login_succeedsApiCall_butFailsToStoreToken_returnsError() async throws {
        let email = Self.email(for: #function)
        let (sut, api, persistence, notifier, flowHandler, userDefaults) = makeSUT()
        clearUserDefaults(for: email, userDefaults: userDefaults)
        let credentials = LoginCredentials(email: email, password: Self.validPassword)
        let expectedTokenValue = Self.anotherValidToken
        let apiResponse = LoginResponse(token: expectedTokenValue)
        api.stubbedResult = .success(apiResponse)
        persistence.saveTokenError = LoginError.tokenStorageFailed

        let result = await sut.login(with: credentials)
        switch result {
        case .success:
            XCTFail("Expected failure, got success")
        case let .failure(error):
            XCTAssertEqual(error, .tokenStorageFailed, "Should return token storage error")
            XCTAssertEqual(notifier.notifiedSuccesses.count, 0, "Notifier should NOT be notified if token storage fails")
            XCTAssertEqual(persistence.savedTokens.count, 0, "Token should not be saved if storage fails")
            XCTAssertEqual(flowHandler.handledResults.count, 1, "FlowHandler should be called on failed token storage")
        }
    }

    func test_login_incrementsFailedAttempts_onInvalidCredentialsError() async {
        let email = Self.email(for: #function)
        let (sut, api, _, _, flowHandler, userDefaults) = makeSUT()
        clearUserDefaults(for: email, userDefaults: userDefaults)
        let credentials = LoginCredentials(email: email, password: Self.invalidPassword)
        api.stubbedResult = Result<LoginResponse, LoginError>.failure(.invalidCredentials)
        _ = await sut.login(with: credentials)

        let wasIncremented = flowHandler.handledResults.contains { result, creds in
            if case let .failure(error) = result,
               error == .invalidCredentials,
               creds.email == credentials.email
            {
                return true
            }
            return false
        }
        XCTAssertTrue(wasIncremented, "FlowHandler should be called with invalid credentials error for the correct user")
    }

    func test_login_doesNotIncrementFailedAttempts_onFormatErrors() async {
        let (sut, _, _, _, flowHandler, _) = makeSUT()
        let credentials = LoginCredentials(email: "invalid", password: Self.validPassword)
        _ = await sut.login(with: credentials)

        let wasCalledForFormatError = flowHandler.handledResults.contains { result, _ in
            if case let .failure(error) = result,
               error == .invalidEmailFormat
            {
                return true
            }
            return false
        }
        XCTAssertTrue(wasCalledForFormatError, "FlowHandler should be called for format errors")
    }

    func test_login_resetsFailedAttempts_onSuccessfulLogin() async {
        let email = Self.email(for: #function)
        let (sut, api, _, _, flowHandler, userDefaults) = makeSUT()
        clearUserDefaults(for: email, userDefaults: userDefaults)
        let credentials = LoginCredentials(email: email, password: Self.validPassword)
        let expectedTokenValue = Self.validToken
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

    func test_login_blocksUser_afterMaxFailedAttempts_andNotifiesLockout() async {
        let email = Self.email(for: #function)
        let maxAttempts = 3
        let lockoutDuration: TimeInterval = 300
        let (sut, api, _, notifier, flowHandler, userDefaults) = makeSUT(
            maxFailedAttempts: maxAttempts,
            lockoutDuration: lockoutDuration
        )
        clearUserDefaults(for: email, userDefaults: userDefaults)
        let credentials = LoginCredentials(email: email, password: Self.invalidPassword)
        api.stubbedResult = .failure(LoginError.invalidCredentials)

        for _ in 1 ... maxAttempts {
            _ = await sut.login(with: credentials)
        }
        let result = await sut.login(with: credentials)

        switch result {
        case let .failure(error):
            if case let .accountLocked(remainingTime) = error {
                XCTAssertTrue(remainingTime > 0 && remainingTime <= Int(lockoutDuration), "Remaining time should be within lockout duration")
            } else {
                XCTFail("Expected accountLocked error with remaining time")
            }

            let lastNotified = notifier.notifiedFailures.compactMap { $0 as? LoginError }.last
            if case let .accountLocked(notifiedRemainingTime)? = lastNotified {
                XCTAssertTrue(notifiedRemainingTime > 0 && notifiedRemainingTime <= Int(lockoutDuration), "Notified remaining time should be within lockout duration")
            } else {
                XCTFail("Notifier should notify accountLocked error with remaining time")
            }

            let lastFlowError = flowHandler.handledResults.compactMap { result, _ in
                if case let .failure(error) = result { return error }
                return nil
            }.last

            if case let .accountLocked(flowRemainingTime)? = lastFlowError {
                XCTAssertTrue(flowRemainingTime > 0 && flowRemainingTime <= Int(lockoutDuration), "FlowHandler should receive accountLocked with remaining time")
            } else {
                XCTFail("FlowHandler should handle accountLocked with remaining time")
            }
        default:
            XCTFail("Expected accountLocked error with remaining time")
        }
    }

    func test_login_allowsRetry_afterLockoutPeriod() async {
        let email = Self.email(for: #function)
        let maxAttempts = 2
        let (sut, api, _, _, _, userDefaults) = makeSUT(maxFailedAttempts: maxAttempts, lockoutDuration: 1)
        clearUserDefaults(for: email, userDefaults: userDefaults)
        let credentials = LoginCredentials(email: email, password: Self.invalidPassword)
        api.stubbedResult = .failure(LoginError.invalidCredentials)

        for _ in 1 ... maxAttempts {
            _ = await sut.login(with: credentials)
        }
        let lockoutResult = await sut.login(with: credentials)
        switch lockoutResult {
        case let .failure(error):
            if case .accountLocked = error {
                // Success - we have an account locked error with remaining time
            } else {
                XCTFail("Expected accountLocked error with remaining time")
            }
        default:
            XCTFail("Expected accountLocked error with remaining time")
        }

        let expectation = expectation(description: "Wait for lockout to expire")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.1) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 2)

        api.stubbedResult = .success(LoginResponse(token: Self.validToken))
        let retryResult = await sut.login(with: LoginCredentials(email: email, password: Self.validPassword))
        switch retryResult {
        case let .success(response):
            XCTAssertEqual(response.token, Self.validToken, "Should allow login after lockout period")
        default:
            XCTFail("Expected successful login after lockout period")
        }
    }

    // MARK: - Helpers

    private func makeSUT(
        maxFailedAttempts: Int = 5,
        lockoutDuration: TimeInterval = 5 * 60,
        file: StaticString = #file, line: UInt = #line
    ) -> (UserLoginUseCase, AuthAPISpy, LoginPersistenceSpy, LoginEventNotifierSpy, LoginFlowHandlerSpy, UserDefaults) {
        let api = AuthAPISpy()
        let persistence = LoginPersistenceSpy()
        let notifier = LoginEventNotifierSpy()
        let flowHandler = LoginFlowHandlerSpy()
        let suiteName = "UserLoginUseCaseTests_\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let sut = UserLoginUseCase(
            api: api,
            persistence: persistence,
            notifier: notifier,
            flowHandler: flowHandler,
            config: UserLoginUseCase.Config(maxFailedAttempts: maxFailedAttempts, lockoutDuration: lockoutDuration),
            userDefaults: userDefaults
        )
        trackForMemoryLeaks(api, file: file, line: line)
        trackForMemoryLeaks(persistence, file: file, line: line)
        trackForMemoryLeaks(notifier, file: file, line: line)
        trackForMemoryLeaks(flowHandler, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, api, persistence, notifier, flowHandler, userDefaults)
    }

    private static func email(for testName: String) -> String {
        let cleaned = testName
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .lowercased()
        return "user+\(cleaned)@example.com"
    }

    private func clearUserDefaults(for email: String, userDefaults: UserDefaults) {
        userDefaults.removeObject(forKey: "login_failed_attempts_" + email)
        userDefaults.removeObject(forKey: "login_lockout_until_" + email)
    }
}

// MARK: - Test Constants

private extension UserLoginUseCaseTests {
    static let validPassword = "password123"
    static let invalidPassword = "wrongpass"
    static let validToken = "jwt-token-123"
    static let anotherValidToken = "token123"
}
