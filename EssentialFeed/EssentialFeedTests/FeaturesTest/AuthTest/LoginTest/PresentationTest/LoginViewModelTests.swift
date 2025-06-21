import EssentialFeed
import XCTest

final class LoginViewModelTests: XCTestCase {
    func test_login_success_whenCredentialsAreValid_shouldSetLoginSuccessAndNoErrorMessage() async {
        let credentials = (email: "carlos@example.com", password: "SafePass123!")
        let (viewModel, loginService) = makeSUT()
        loginService.stubbedResult = .success(LoginResponse(
            user: User(name: "Test User", email: credentials.email),
            token: Token(accessToken: "test-token", expiry: Date().addingTimeInterval(3600), refreshToken: nil)
        ))
        viewModel.username = credentials.email
        viewModel.password = credentials.password
        await viewModel.login()
        XCTAssertTrue(viewModel.loginSuccess)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_login_failure_whenInvalidCredentials_shouldShowInvalidCredentialsMessage() async {
        let credentials = (email: "fail@example.com", password: "WrongPass1")
        let (viewModel, loginService) = makeSUT()
        loginService.stubbedResult = .failure(.invalidCredentials)
        viewModel.username = credentials.email
        viewModel.password = credentials.password
        await viewModel.login()
        XCTAssertFalse(viewModel.loginSuccess)
        let expectedMessage = "Invalid username or password."
        XCTAssertEqual(viewModel.errorMessage, expectedMessage)
    }

    func test_login_networkError_whenNoConnectivity_shouldShowNetworkErrorMessage() async {
        let credentials = (email: "john@example.com", password: "SafePass123!")
        let (viewModel, loginService) = makeSUT()
        loginService.stubbedResult = .failure(.noConnectivity)
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
        loginService: LoginServiceSpy
    ) {
        let loginService = LoginServiceSpy()
        let useCase = UserLoginUseCase(loginService: loginService)
        let viewModel = LoginViewModel(authenticate: { username, password in
            await useCase.login(with: LoginCredentials(email: username, password: password))
        })
        trackForMemoryLeaks(loginService, file: file, line: line)
        trackForMemoryLeaks(useCase, file: file, line: line)
        trackForMemoryLeaks(viewModel, file: file, line: line)
        return (viewModel, loginService)
    }

    // MARK: - Test Doubles

    private class LoginServiceSpy: LoginService {
        private(set) var executeCallCount = 0
        private(set) var lastCredentials: LoginCredentials?
        var stubbedResult: Result<LoginResponse, LoginError> = .failure(.invalidCredentials)

        func execute(credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
            executeCallCount += 1
            lastCredentials = credentials
            return stubbedResult
        }
    }
}

// MARK: - Dummy observers

private final class DummySuccessObserver: LoginSuccessObserver {
    func didLoginSuccessfully(response _: LoginResponse) {}
}

private final class DummyFailureObserver: LoginFailureObserver {
    func didFailLogin(error _: Error) {}
}
