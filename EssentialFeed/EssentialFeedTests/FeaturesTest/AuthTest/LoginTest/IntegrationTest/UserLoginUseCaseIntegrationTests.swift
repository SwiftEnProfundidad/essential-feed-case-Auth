
import EssentialFeed
import XCTest

final class UserLoginUseCaseIntegrationTests: XCTestCase {
    func test_login_doesNotCallAPI_whenEmailIsInvalid() async {
        let (sut, api, _, _, _) = makeSUT()
        let credentials = LoginCredentials(email: "", password: "ValidPassword123")
        _ = await sut.login(with: credentials)
        XCTAssertFalse(api.wasCalled, "API should NOT be called when email is invalid")
    }

    func test_login_doesNotCallAPI_whenPasswordIsInvalid() async {
        let (sut, api, _, _, _) = makeSUT()
        let credentials = LoginCredentials(email: "user@example.com", password: "   ")
        _ = await sut.login(with: credentials)
        XCTAssertFalse(api.wasCalled, "API should NOT be called when password is invalid")
    }

    // TODO: Si existe Keychain/secure storage en el flujo, añadir spy y test equivalente:
    // func test_login_doesNotAccessKeychain_whenValidationFails() async { ... }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: UserLoginUseCase,
        api: AuthAPISpy,
        successSpy: LoginSuccessObserverSpy,
        failureSpy: LoginFailureObserverSpy,
        failedAttemptsStore: FailedLoginAttemptsStoreSpy
    ) {
        let api = AuthAPISpy()
        let offlineStore = OfflineLoginStoreSpy()
        let tokenStorage = TokenStorageSpy()
        let successSpy = LoginSuccessObserverSpy()
        let failureSpy = LoginFailureObserverSpy()
        let failedAttemptsStore = FailedLoginAttemptsStoreSpy()
        let sut = UserLoginUseCase(
            api: api,
            tokenStorage: tokenStorage,
            offlineStore: offlineStore,
            failedAttemptsStore: failedAttemptsStore,
            successObserver: successSpy,
            failureObserver: failureSpy
        )

        trackForMemoryLeaks(api, file: file, line: line)
        trackForMemoryLeaks(offlineStore, file: file, line: line)
        trackForMemoryLeaks(tokenStorage, file: file, line: line)
        trackForMemoryLeaks(successSpy, file: file, line: line)
        trackForMemoryLeaks(failureSpy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)

        return (sut, api, successSpy, failureSpy, failedAttemptsStore)
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
