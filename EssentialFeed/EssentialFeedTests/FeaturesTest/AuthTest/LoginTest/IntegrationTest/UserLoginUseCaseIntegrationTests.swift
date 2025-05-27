
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
