
import EssentialFeed
import XCTest

final class LoginViewModelTests: XCTestCase {
    func test_login_success_whenCredentialsAreValid_shouldSetLoginSuccessAndNoErrorMessage() async {
        let credentials = (email: "carlos@example.com", password: "SafePass123!")
        let (viewModel, api, _, _, _, _, _) = makeSUT()
        api.stubbedResult = .success(LoginResponse(token: "test-token"))
        viewModel.username = credentials.email
        viewModel.password = credentials.password
        await viewModel.login()
        XCTAssertTrue(viewModel.loginSuccess)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_login_failure_whenInvalidCredentials_shouldShowInvalidCredentialsMessage() async {
        let credentials = (email: "fail@example.com", password: "WrongPass1")
        let (viewModel, api, _, _, _, _, _) = makeSUT()
        api.stubbedResult = .failure(.invalidCredentials)
        viewModel.username = credentials.email
        viewModel.password = credentials.password
        await viewModel.login()
        XCTAssertFalse(viewModel.loginSuccess)
        let expectedMessage = DefaultLoginBlockMessageProvider().message(for: LoginError.invalidCredentials)
        XCTAssertEqual(viewModel.errorMessage, expectedMessage)
    }

    func test_login_networkError_whenNoConnectivity_shouldShowNetworkErrorMessage() async {
        let credentials = (email: "john@example.com", password: "SafePass123!")
        let (viewModel, api, _, _, _, _, _) = makeSUT()
        api.stubbedResult = .failure(.noConnectivity)
        viewModel.username = credentials.email
        viewModel.password = credentials.password
        await viewModel.login()
        XCTAssertFalse(viewModel.loginSuccess)
        let expectedMessage = DefaultLoginBlockMessageProvider().message(for: LoginError.noConnectivity)
        XCTAssertEqual(viewModel.errorMessage, expectedMessage)
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        viewModel: LoginViewModel,
        api: AuthAPISpy,
        persistence: LoginPersistenceSpy,
        notifier: LoginEventNotifierSpy,
        flowHandler: LoginFlowHandlerSpy,
        lockStatusProvider: LoginLockStatusProviderSpy,
        failedLoginHandler: FailedLoginHandlerSpy
    ) {
        let api = AuthAPISpy()
        let persistence = LoginPersistenceSpy()
        let notifier = LoginEventNotifierSpy()
        let flowHandler = LoginFlowHandlerSpy()
        let lockStatusProvider = LoginLockStatusProviderSpy()
        let failedLoginHandler = FailedLoginHandlerSpy()
        let config = UserLoginConfiguration(maxFailedAttempts: 5, lockoutDuration: 300, tokenDuration: 3600)
        let useCase = UserLoginUseCase(
            api: api,
            persistence: persistence,
            notifier: notifier,
            flowHandler: flowHandler,
            lockStatusProvider: lockStatusProvider,
            failedLoginHandler: failedLoginHandler,
            config: config
        )
        let viewModel = LoginViewModel(authenticate: { username, password in
            await useCase.login(with: LoginCredentials(email: username, password: password))
        })
        trackForMemoryLeaks(api, file: file, line: line)
        trackForMemoryLeaks(persistence, file: file, line: line)
        trackForMemoryLeaks(notifier, file: file, line: line)
        trackForMemoryLeaks(flowHandler, file: file, line: line)
        trackForMemoryLeaks(lockStatusProvider, file: file, line: line)
        trackForMemoryLeaks(failedLoginHandler, file: file, line: line)
        trackForMemoryLeaks(useCase, file: file, line: line)
        trackForMemoryLeaks(viewModel, file: file, line: line)
        return (viewModel, api, persistence, notifier, flowHandler, lockStatusProvider, failedLoginHandler)
    }
}

// MARK: - Dummy observers

private final class DummySuccessObserver: LoginSuccessObserver {
    func didLoginSuccessfully(response _: LoginResponse) {}
}

private final class DummyFailureObserver: LoginFailureObserver {
    func didFailLogin(error _: Error) {}
}
