import EssentialFeed
import XCTest

final class LoginViewModelTests: XCTestCase {
    func test_login_success() async {
        let mockAPI = MockAuthAPI()
        mockAPI.loginHandler = { _ in
            .success(LoginResponse(token: "test-token"))
        }
        let useCase = UserLoginUseCase(api: mockAPI)
        let viewModel = LoginViewModel(authenticate: { username, password in
            await useCase.login(with: LoginCredentials(email: username, password: password))
        })
        viewModel.username = "carlos"
        viewModel.password = "claveSegura123"

        await viewModel.login()

        XCTAssertTrue(viewModel.loginSuccess)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_login_failure_showsError() async {
        let mockAPI = MockAuthAPI()
        mockAPI.loginHandler = { _ in
            .failure(.invalidCredentials)
        }
        let useCase = UserLoginUseCase(api: mockAPI)
        let viewModel = LoginViewModel(authenticate: { username, password in
            await useCase.login(with: LoginCredentials(email: username, password: password))
        })
        viewModel.username = "fail"
        viewModel.password = "wrong"

        await viewModel.login()

        XCTAssertFalse(viewModel.loginSuccess)
        XCTAssertEqual(viewModel.errorMessage, LoginError.invalidCredentials.localizedDescription)
    }

    func test_login_networkError() async {
        let mockAPI = MockAuthAPI()
        mockAPI.loginHandler = { _ in
            .failure(.network)
        }
        let useCase = UserLoginUseCase(api: mockAPI)
        let viewModel = LoginViewModel(authenticate: { username, password in
            await useCase.login(with: LoginCredentials(email: username, password: password))
        })
        viewModel.username = "carlos"
        viewModel.password = "claveSegura123"

        await viewModel.login()

        XCTAssertFalse(viewModel.loginSuccess)
        XCTAssertEqual(viewModel.errorMessage, LoginError.network.localizedDescription)
    }
}
