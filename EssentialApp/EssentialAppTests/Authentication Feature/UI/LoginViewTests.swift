import XCTest
import SwiftUI
import EssentialApp
import EssentialFeed

final class LoginViewTests: XCTestCase {
	
	func test_login_withInvalidEmail_showsValidationError() async {
		// Arrange
		let viewModel = makeSUT(authenticate: { _, _ in .failure(.invalidEmailFormat) })
		viewModel.username = "invalid-email"
		viewModel.password = "password"
		// Act
		await viewModel.login()
		// Assert
		XCTAssertEqual(viewModel.errorMessage, "Email format is invalid.")
	}
	
	func test_login_withEmptyPassword_showsValidationError() async {
		let viewModel = makeSUT(authenticate: { _, _ in .failure(.invalidPasswordFormat) })
		viewModel.username = "user@email.com"
		viewModel.password = ""
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Password cannot be empty.")
	}
	
	func test_login_withValidCredentials_triggersAuthentication() async {
		let exp = expectation(description: "Authentication triggered")
		let viewModel = makeSUT(authenticate: { username, password in
			XCTAssertEqual(username, "user@email.com")
			XCTAssertEqual(password, "password")
			exp.fulfill()
			return .success(LoginResponse(token: "token"))
		})
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		await fulfillment(of: [exp], timeout: 1.0)    }
	
	func test_login_withInvalidCredentials_showsAuthenticationError() async {
		let viewModel = makeSUT()
		viewModel.username = "user@email.com"
		viewModel.password = "wrongpass"
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Invalid credentials.")
	}
	
	func test_login_success_showsSuccessFeedback() async {
		let viewModel = makeSUT(authenticate: { _, _ in .success(LoginResponse(token: "token")) })
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertTrue(viewModel.loginSuccess)
	}
	
	func test_login_networkError_showsNetworkErrorMessage() async {
		let viewModel = makeSUT(authenticate: { _, _ in .failure(.network) })
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Could not connect. Please try again.")
	}
	
	func test_login_error_showsErrorFeedback() async {
		let viewModel = makeSUT(authenticate: { _, _ in .failure(.unknown) })
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Something went wrong. Please try again.")
	}
	
	func test_editingUsernameOrPassword_clearsErrorMessage() async {
		let viewModel = makeSUT()
		viewModel.username = "user@email.com"
		viewModel.password = "wrongpass"
		await viewModel.login()
		XCTAssertNotNil(viewModel.errorMessage, "Expected errorMessage to be present after failed login")
		
		// Simula que el usuario corrige el email
		viewModel.username = "new@email.com"
		XCTAssertNil(viewModel.errorMessage, "Expected errorMessage to be nil after editing username, but got: \(viewModel.errorMessage ?? "nil")")
		
		// Vuelve a poner el error
		viewModel.username = "user@email.com"
		viewModel.password = "wrongpass"
		await viewModel.login()
		XCTAssertNotNil(viewModel.errorMessage, "Expected errorMessage to be present after failed login")
		
		// Simula que el usuario corrige la contraseña
		viewModel.password = "newpassword"
		XCTAssertNil(viewModel.errorMessage, "Expected errorMessage to be nil after editing password, but got: \(viewModel.errorMessage ?? "nil")")
	}
	
	func test_loginSuccessFlag_isTrueAfterSuccessAndFalseAfterFailure() async {
		let viewModel = makeSUT(authenticate: { _, _ in .success(LoginResponse(token: "token")) })
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertTrue(viewModel.loginSuccess, "Expected loginSuccess to be true after successful login")
		
		// Ahora simula un login fallido
		let failingVM = makeSUT()
		failingVM.username = "user@email.com"
		failingVM.password = "wrongpass"
		await failingVM.login()
		XCTAssertFalse(failingVM.loginSuccess, "Expected loginSuccess to be false after failed login")
	}
	
	func test_successfulLogin_clearsPreviousErrorMessage() async {
		// Primer intento: error
		let failingViewModel = makeSUT()
		failingViewModel.username = "user@email.com"
		failingViewModel.password = "wrongpass"
		await failingViewModel.login()
		XCTAssertNotNil(failingViewModel.errorMessage, "Expected errorMessage to be present after failed login")
		
		// Segundo intento: éxito, usando un nuevo ViewModel
		let successViewModel = makeSUT(authenticate: { _, _ in .success(LoginResponse(token: "token")) })
		successViewModel.username = "user@email.com"
		successViewModel.password = "password"
		await successViewModel.login()
		XCTAssertNil(successViewModel.errorMessage, "Expected errorMessage to be nil after successful login, but got: \(successViewModel.errorMessage ?? "nil")")
		XCTAssertTrue(successViewModel.loginSuccess, "Expected loginSuccess to be true after successful login")
	}
	
	func test_usernameAndPassword_arePublishedAndObservable() async {
		let viewModel = makeSUT()
		let expectedUsername = "test@email.com"
		let expectedPassword = "testpass123"
		viewModel.username = expectedUsername
		viewModel.password = expectedPassword
		XCTAssertEqual(viewModel.username, expectedUsername, "Expected username to be published and observable")
		XCTAssertEqual(viewModel.password, expectedPassword, "Expected password to be published and observable")
	}
	
	func test_onSuccessAlertDismissed_executesCallback() async {
		let viewModel = makeSUT(authenticate: { _, _ in .success(LoginResponse(token: "token")) })
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertTrue(viewModel.loginSuccess, "Expected loginSuccess to be true after successful login")
		
		var callbackCalled = false
		viewModel.onAuthenticated = {
			callbackCalled = true
		}
		viewModel.onSuccessAlertDismissed()
		XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false after dismissing alert")
		XCTAssertTrue(callbackCalled, "Expected onAuthenticated callback to be called after alert dismissed")
	}
	
	func test_initialState_isClean() async {
		let viewModel = makeSUT()
		XCTAssertNil(viewModel.errorMessage, "Expected errorMessage to be nil on initial state")
		XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false on initial state")
		XCTAssertEqual(viewModel.username, "", "Expected username to be empty on initial state")
		XCTAssertEqual(viewModel.password, "", "Expected password to be empty on initial state")
	}
	
	func test_login_withEmptyFields_showsValidationError() async {
		let viewModel = makeSUT()
		viewModel.username = ""
		viewModel.password = ""
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Email format is invalid.", "Expected validation error when username is empty")
		XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false when login fails due to validation")
	}
	
	// MARK: Helpers
	
	private func makeSUT(
		authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError> = { _, _ in .failure(.invalidCredentials) } ) -> LoginViewModel {
			let sut = LoginViewModel(authenticate: authenticate)
			_ = LoginView(viewModel: sut)
			return sut
		}
}
