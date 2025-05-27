
import EssentialFeed
import XCTest

final class UserLoginUseCaseIntegrationTests: XCTestCase {
    func test_login_doesNotCallAPI_whenEmailIsInvalid() async {
        let (sut, api) = makeSUT()
        let credentials = LoginCredentials(email: "", password: "ValidPassword123")
        _ = await sut.login(with: credentials)
        XCTAssertFalse(api.wasCalled, "API should NOT be called when email is invalid")
    }

    func test_login_doesNotCallAPI_whenPasswordIsInvalid() async {
        let (sut, api) = makeSUT()
        let credentials = LoginCredentials(email: "user@example.com", password: "   ")
        _ = await sut.login(with: credentials)
        XCTAssertFalse(api.wasCalled, "API should NOT be called when password is invalid")
    }

    func test_login_withValidCredentials_notifiesSuccessObserver_andUIShowsSuccess() async {
        let (sut, api) = makeSUT()
        let credentials = LoginCredentials(email: "success@example.com", password: "ValidPassword123")
        let expectedResponse = LoginResponse(token: "VALID_TOKEN")
        api.stubbedResult = .success(expectedResponse)
        let successObserver = LoginSuccessObserverSpy()
        sut.successObserver = successObserver
        let _ = await sut.login(with: credentials)
        XCTAssertEqual(successObserver.receivedResponses, [expectedResponse], "Success observer should be notified with the correct response")
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: UserLoginUseCase, api: AuthAPISpy) {
        let api = AuthAPISpy()
        let persistence = LoginPersistenceSpy()
        let notifier = LoginEventNotifierSpy()
        let flowHandler = LoginFlowHandlerSpy()
        let lockStatusProvider = LoginLockStatusProviderSpy()
        let failedLoginHandler = FailedLoginHandlerSpy()
        let config = UserLoginConfiguration(maxFailedAttempts: 5, lockoutDuration: 300, tokenDuration: 3600)
        let sut = UserLoginUseCase(
            api: api,
            persistence: persistence,
            notifier: notifier,
            flowHandler: flowHandler,
            lockStatusProvider: lockStatusProvider,
            failedLoginHandler: failedLoginHandler,
            config: config
        )
        trackForMemoryLeaks(api, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, api)
    }

    private final class LoginSuccessObserverSpy: LoginSuccessObserver {
        private(set) var receivedResponses = [LoginResponse]()
        func didLoginSuccessfully(response: LoginResponse) {
            receivedResponses.append(response)
        }
    }

    private final class LoginFailureObserverSpy: LoginFailureObserver {
        private(set) var receivedErrors = [Error]()
        func didFailLogin(error: Error) {
            receivedErrors.append(error)
        }
    }
}
