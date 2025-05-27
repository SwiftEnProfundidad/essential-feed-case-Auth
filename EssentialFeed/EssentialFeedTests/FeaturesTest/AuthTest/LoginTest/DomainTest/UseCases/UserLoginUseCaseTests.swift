import EssentialFeed
import Foundation
import XCTest

final class UserLoginUseCaseTests: XCTestCase {
    private let validEmail = "user@example.com"
    private let validPassword = "password123"
    private let invalidPassword = "wrongpass"
    private let validToken = "token123"

    func test_login_withInvalidPasswordFormat_failsAndDoesNotCallAPI() async {
        let (sut, api, _, notifier, flowHandler, _, failedLoginSpy) = makeSUT()
        let credentials = LoginCredentials(email: validEmail, password: "")

        let result = await sut.login(with: credentials)

        switch result {
        case let .failure(error):
            XCTAssertEqual(error, LoginError.invalidPasswordFormat)
            XCTAssertFalse(api.wasCalled)
            XCTAssertEqual(notifier.notifiedFailures.count, 1)
            XCTAssertEqual(flowHandler.handledResults.count, 1)
            XCTAssertTrue(failedLoginSpy.handleFailedLoginCalls.isEmpty)
        default:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_withInvalidCredentials_incrementsFailedAttempts() async {
        let (sut, api, _, _, flowHandler, _, failedLoginSpy) = makeSUT()
        let credentials = LoginCredentials(email: validEmail, password: invalidPassword)
        api.stubbedResult = .failure(LoginError.invalidCredentials)

        let result = await sut.login(with: credentials)

        switch result {
        case let .failure(error):
            XCTAssertEqual(error, LoginError.invalidCredentials)
            XCTAssertEqual(flowHandler.handledResults.count, 1)
            XCTAssertEqual(failedLoginSpy.handleFailedLoginCalls, [validEmail])
        default:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_successful_resetsAttempts_andPersistsToken_andNotifies() async {
        let email = "user@example.com"
        let password = "password123"
        let token = "token123"
        let (sut, api, persistence, notifier, flowHandler, _, failedLoginSpy) = makeSUT()
        let credentials = LoginCredentials(email: email, password: password)
        let apiResponse = LoginResponse(token: token)
        api.stubbedResult = .success(apiResponse)

        let result = await sut.login(with: credentials)

        switch result {
        case let .success(response):
            XCTAssertEqual(response.token, validToken)
            XCTAssertEqual(persistence.savedTokens.count, 1)
            XCTAssertEqual(persistence.savedTokens.first?.accessToken, validToken)
            XCTAssertEqual(notifier.notifiedSuccesses.count, 1)
            XCTAssertEqual(flowHandler.handledResults.count, 1)
            XCTAssertEqual(failedLoginSpy.resetAttemptsCalls, [validEmail])
        default:
            XCTFail("Expected success, got failure")
        }
    }

    func test_login_successful_butPersistenceFails_returnsError() async {
        let (sut, api, persistence, _, flowHandler, _, _) = makeSUT()
        let credentials = LoginCredentials(email: validEmail, password: validPassword)
        let apiResponse = LoginResponse(token: validToken)
        api.stubbedResult = .success(apiResponse)
        persistence.saveTokenError = LoginError.tokenStorageFailed

        let result = await sut.login(with: credentials)

        switch result {
        case let .failure(error):
            XCTAssertEqual(error, LoginError.tokenStorageFailed)
            XCTAssertEqual(persistence.savedTokens.count, 0)
            XCTAssertEqual(flowHandler.handledResults.count, 1)
        default:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_whenAccountIsLocked_deliversAccountLockedError() async {
        let (sut, _, _, notifier, flowHandler, lockStatusSpy, _) = makeSUT()
        let credentials = LoginCredentials(email: validEmail, password: validPassword)
        lockStatusSpy.lockedUsers = [validEmail]
        lockStatusSpy.remainingTime = 123

        let result = await sut.login(with: credentials)

        switch result {
        case let .failure(error):
            if case let LoginError.accountLocked(remainingTime) = error {
                XCTAssertEqual(remainingTime, 123)
            } else {
                XCTFail("Expected accountLocked error, got \(error)")
            }
            XCTAssertEqual(notifier.notifiedFailures.last as? LoginError, LoginError.accountLocked(remainingTime: 123))
            XCTAssertEqual(flowHandler.handledResults.last?.0, .failure(LoginError.accountLocked(remainingTime: 123)))
        default:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_blocksUser_afterMaxFailedAttempts() async {
        let maxAttempts = 2
        let email = "user@example.com"
        let (sut, api, _, notifier, flowHandler, lockStatusSpy, _) = makeSUT(maxFailedAttempts: maxAttempts, lockoutDuration: 300)
        let credentials = LoginCredentials(email: email, password: "wrongpass")
        api.stubbedResult = .failure(LoginError.invalidCredentials)
        lockStatusSpy.lockedUsers = [email]
        lockStatusSpy.remainingTime = 77

        for _ in 1 ... maxAttempts {
            _ = await sut.login(with: credentials)
        }
        let result = await sut.login(with: credentials)

        switch result {
        case let .failure(error):
            if case let LoginError.accountLocked(remainingTime) = error {
                XCTAssertEqual(remainingTime, 77)
            } else {
                XCTFail("Expected accountLocked error, got \(error)")
            }
            XCTAssertEqual(notifier.notifiedFailures.last as? LoginError, LoginError.accountLocked(remainingTime: 77))
            XCTAssertEqual(flowHandler.handledResults.last?.0, .failure(LoginError.accountLocked(remainingTime: 77)))
        default:
            XCTFail("Expected accountLocked error with remaining time")
        }
    }

    func test_login_allowsRetry_afterLockoutPeriod() async {
        let maxAttempts = 2
        let email = "user@example.com"
        let (sut, api, _, _, _, lockStatusSpy, _) = makeSUT(maxFailedAttempts: maxAttempts, lockoutDuration: 1)
        let credentials = LoginCredentials(email: email, password: "wrongpass")
        api.stubbedResult = .failure(LoginError.invalidCredentials)
        lockStatusSpy.lockedUsers = [email]
        lockStatusSpy.remainingTime = 1

        for _ in 1 ... maxAttempts {
            _ = await sut.login(with: credentials)
        }
        let lockoutResult = await sut.login(with: credentials)
        switch lockoutResult {
        case let .failure(error):
            if case LoginError.accountLocked = error {
            } else {
                XCTFail("Expected accountLocked error with remaining time")
            }
        default:
            XCTFail("Expected accountLocked error with remaining time")
        }
        lockStatusSpy.lockedUsers = []
        api.stubbedResult = .success(LoginResponse(token: validToken))
        let retryResult = await sut.login(with: LoginCredentials(email: validEmail, password: validPassword))
        switch retryResult {
        case let .success(response):
            XCTAssertEqual(response.token, validToken)
        default:
            XCTFail("Expected successful login after lockout period")
        }
    }

    // MARK: - Helpers

    private func makeSUT(maxFailedAttempts: Int = 5, lockoutDuration: TimeInterval = 300) -> (UserLoginUseCase, AuthAPISpy, LoginPersistenceSpy, LoginEventNotifierSpy, LoginFlowHandlerSpy, LoginLockStatusProviderSpy, FailedLoginHandlerSpy) {
        let api = AuthAPISpy()
        let persistence = LoginPersistenceSpy()
        let notifier = LoginEventNotifierSpy()
        let flowHandler = LoginFlowHandlerSpy()
        let lockStatusSpy = LoginLockStatusProviderSpy()
        let failedLoginSpy = FailedLoginHandlerSpy()
        let config = UserLoginConfiguration(maxFailedAttempts: maxFailedAttempts, lockoutDuration: lockoutDuration, tokenDuration: 3600)
        let sut = UserLoginUseCase(
            api: api,
            persistence: persistence,
            notifier: notifier,
            flowHandler: flowHandler,
            lockStatusProvider: lockStatusSpy,
            failedLoginHandler: failedLoginSpy,
            config: config
        )
        return (sut, api, persistence, notifier, flowHandler, lockStatusSpy, failedLoginSpy)
    }
}
