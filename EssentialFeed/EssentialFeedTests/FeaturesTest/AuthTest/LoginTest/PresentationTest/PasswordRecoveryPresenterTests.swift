import EssentialFeed
import XCTest

final class PasswordRecoveryPresenterTests: XCTestCase {
    func test_map_deliversSuccessViewModel_onSuccessfulRecovery() {
        let response = PasswordRecoveryResponse(message: "Check your email")

        let viewModel = PasswordRecoveryPresenter.map(.success(response))

        XCTAssertEqual(viewModel, PasswordRecoveryViewModel(message: "Check your email", isSuccess: true))
    }

    func test_map_deliversInvalidEmailErrorViewModel_onInvalidEmailError() {
        let viewModel = PasswordRecoveryPresenter.map(.failure(.invalidEmailFormat))

        XCTAssertEqual(viewModel, PasswordRecoveryViewModel(message: "Email format is not valid.", isSuccess: false))
    }

    func test_map_deliversEmailNotFoundErrorViewModel_onEmailNotFoundError() {
        let viewModel = PasswordRecoveryPresenter.map(.failure(.emailNotFound))

        XCTAssertEqual(viewModel, PasswordRecoveryViewModel(message: "No account associated with that email.", isSuccess: false))
    }

    func test_map_deliversNetworkErrorViewModel_onNetworkError() {
        let viewModel = PasswordRecoveryPresenter.map(.failure(.network))

        XCTAssertEqual(viewModel, PasswordRecoveryViewModel(message: "Connection error. Please try again.", isSuccess: false))
    }

    func test_map_deliversRateLimitErrorViewModel_onRateLimitError() {
        let viewModel = PasswordRecoveryPresenter.map(.failure(.rateLimitExceeded(retryAfterSeconds: 300)))

        XCTAssertEqual(viewModel, PasswordRecoveryViewModel(message: "Too many attempts. Please try again in 5 minutes.", isSuccess: false))
    }

    func test_map_deliversRateLimitErrorViewModel_withSecondsOnly() {
        let viewModel = PasswordRecoveryPresenter.map(.failure(.rateLimitExceeded(retryAfterSeconds: 30)))

        XCTAssertEqual(viewModel, PasswordRecoveryViewModel(message: "Too many attempts. Please try again in a few seconds.", isSuccess: false))
    }

    func test_map_deliversUnknownErrorViewModel_onUnknownError() {
        let viewModel = PasswordRecoveryPresenter.map(.failure(.unknown))

        XCTAssertEqual(viewModel, PasswordRecoveryViewModel(message: "Unknown error. Please try again.", isSuccess: false))
    }
}
