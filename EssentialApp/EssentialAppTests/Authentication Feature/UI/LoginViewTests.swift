import XCTest
import SwiftUI
import EssentialApp
import EssentialFeed

final class LoginViewTests: XCTestCase {
	func test_login_withInvalidEmail_showsValidationError() async {
		// Arrange
		let viewModel = LoginViewModel(authenticate: { _, _ in .failure(.invalidEmailFormat) })
		_ = await LoginView(viewModel: viewModel)
		viewModel.username = "invalid-email"
		viewModel.password = "password"
		// Act
		await viewModel.login()
		// Assert
		XCTAssertEqual(viewModel.errorMessage, "Email format is invalid.")
	}
	
	func test_login_withEmptyPassword_showsValidationError() async {
		let viewModel = LoginViewModel(authenticate: { _, _ in .failure(.invalidPasswordFormat) })
		_ = await LoginView(viewModel: viewModel)
		viewModel.username = "user@email.com"
		viewModel.password = ""
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Password cannot be empty.")
	}
	
	func test_login_withValidCredentials_triggersAuthentication() async {
		let exp = expectation(description: "Authentication triggered")
		let viewModel = LoginViewModel(authenticate: { username, password in
			XCTAssertEqual(username, "user@email.com")
			XCTAssertEqual(password, "password")
			exp.fulfill()
			return .success(LoginResponse(token: "token"))
		})
		_ = await LoginView(viewModel: viewModel)
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		await fulfillment(of: [exp], timeout: 1.0)    }
	
	func test_login_withInvalidCredentials_showsAuthenticationError() async {
		let viewModel = LoginViewModel(authenticate: { _, _ in .failure(.invalidCredentials) })
		_ = await LoginView(viewModel: viewModel)
		viewModel.username = "user@email.com"
		viewModel.password = "wrongpass"
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Invalid credentials.")
	}
	
	func test_login_success_showsSuccessFeedback() async {
		let viewModel = LoginViewModel(authenticate: { _, _ in .success(LoginResponse(token: "token")) })
		_ = await LoginView(viewModel: viewModel)
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertTrue(viewModel.loginSuccess)
	}
	
	func test_login_networkError_showsNetworkErrorMessage() async {
		let viewModel = LoginViewModel(authenticate: { _, _ in .failure(.network) })
		_ = await LoginView(viewModel: viewModel)
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Could not connect. Please try again.")
	}
	
	func test_login_error_showsErrorFeedback() async {
		let viewModel = LoginViewModel(authenticate: { _, _ in .failure(.unknown) })
		_ = await LoginView(viewModel: viewModel)
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Something went wrong. Please try again.")
	}
}
