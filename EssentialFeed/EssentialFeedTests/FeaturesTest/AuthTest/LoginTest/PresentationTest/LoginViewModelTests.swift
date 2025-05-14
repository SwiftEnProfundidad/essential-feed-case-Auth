
import EssentialFeed
import XCTest

final class LoginViewModelTests: XCTestCase {
    func test_login_success() async {
        let api = AuthAPISpy()
        api.stubbedResult = .success(LoginResponse(token: "test-token"))

        let (viewModel, _) = makeSUT(api: api)
        viewModel.username = "carlos@example.com"
        viewModel.password = "SafePass123!"

        await viewModel.login()

        XCTAssertTrue(viewModel.loginSuccess)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_login_failure_showsError() async {
        let api = AuthAPISpy()
        api.stubbedResult = .failure(.invalidCredentials)

        let (viewModel, _) = makeSUT(api: api)
        viewModel.username = "fail@example.com"
        viewModel.password = "WrongPass1"

        await viewModel.login()

        XCTAssertFalse(viewModel.loginSuccess)

        let expectedInvalidMessage = DefaultLoginBlockMessageProvider().message(for: LoginError.invalidCredentials)
        XCTAssertEqual(viewModel.errorMessage, expectedInvalidMessage)
    }

    func test_login_networkError() async {
        let api = AuthAPISpy()
        api.stubbedResult = .failure(.noConnectivity)

        let (viewModel, _) = makeSUT(api: api)
        viewModel.username = "john@example.com"
        viewModel.password = "SafePass123!"

        await viewModel.login()

        XCTAssertFalse(viewModel.loginSuccess)

        let expectedNetworkMessage = DefaultLoginBlockMessageProvider().message(for: LoginError.noConnectivity)
        XCTAssertEqual(viewModel.errorMessage, expectedNetworkMessage)
    }

    // MARK: - Helpers

    private func makeSUT(
        api: AuthAPISpy,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (viewModel: LoginViewModel, useCase: UserLoginUseCase) {
        let persistence = LoginPersistenceSpy()
        let notifier = LoginEventNotifierSpy()
        let flowHandler = LoginFlowHandlerSpy()
        let useCase = UserLoginUseCase(
            api: api,
            persistence: persistence,
            notifier: notifier,
            flowHandler: flowHandler
        )
        let viewModel = LoginViewModel(authenticate: { username, password in
            await useCase.login(with: LoginCredentials(email: username, password: password))
        })
        trackForMemoryLeaks(api, file: file, line: line)
        trackForMemoryLeaks(persistence, file: file, line: line)
        trackForMemoryLeaks(notifier, file: file, line: line)
        trackForMemoryLeaks(flowHandler, file: file, line: line)
        trackForMemoryLeaks(useCase, file: file, line: line)
        trackForMemoryLeaks(viewModel, file: file, line: line)
        return (viewModel, useCase)
    }
}

// MARK: - Dummy observers

private final class DummySuccessObserver: LoginSuccessObserver {
    func didLoginSuccessfully(response _: LoginResponse) {}
}

private final class DummyFailureObserver: LoginFailureObserver {
    func didFailLogin(error _: Error) {}
}
