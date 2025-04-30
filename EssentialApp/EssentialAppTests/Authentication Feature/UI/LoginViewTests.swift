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
	
	func test_editingUsernameOrPassword_clearsErrorMessage() async {
		let viewModel = LoginViewModel(authenticate: { _, _ in .failure(.invalidCredentials) })
		_ = await LoginView(viewModel: viewModel)
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
		let viewModel = LoginViewModel(authenticate: { _, _ in .success(LoginResponse(token: "token")) })
		_ = await LoginView(viewModel: viewModel)
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertTrue(viewModel.loginSuccess, "Expected loginSuccess to be true after successful login")
		
		// Ahora simula un login fallido
		let failingVM = LoginViewModel(authenticate: { _, _ in .failure(.invalidCredentials) })
		_ = await LoginView(viewModel: failingVM)
		failingVM.username = "user@email.com"
		failingVM.password = "wrongpass"
		await failingVM.login()
		XCTAssertFalse(failingVM.loginSuccess, "Expected loginSuccess to be false after failed login")
	}
	
	func test_successfulLogin_clearsPreviousErrorMessage() async {
		// Primer intento: error
		let failingViewModel = LoginViewModel(authenticate: { _, _ in .failure(.invalidCredentials) })
		_ = await LoginView(viewModel: failingViewModel)
		failingViewModel.username = "user@email.com"
		failingViewModel.password = "wrongpass"
		await failingViewModel.login()
		XCTAssertNotNil(failingViewModel.errorMessage, "Expected errorMessage to be present after failed login")
		
		// Segundo intento: éxito, usando un nuevo ViewModel
		let successViewModel = LoginViewModel(authenticate: { _, _ in .success(LoginResponse(token: "token")) })
		_ = await LoginView(viewModel: successViewModel)
		successViewModel.username = "user@email.com"
		successViewModel.password = "password"
		await successViewModel.login()
		XCTAssertNil(successViewModel.errorMessage, "Expected errorMessage to be nil after successful login, but got: \(successViewModel.errorMessage ?? "nil")")
		XCTAssertTrue(successViewModel.loginSuccess, "Expected loginSuccess to be true after successful login")
	}
	
	func test_usernameAndPassword_arePublishedAndObservable() async {
		let viewModel = LoginViewModel(authenticate: { _, _ in .failure(.invalidCredentials) })
		_ = await LoginView(viewModel: viewModel)
		let expectedUsername = "test@email.com"
		let expectedPassword = "testpass123"
		viewModel.username = expectedUsername
		viewModel.password = expectedPassword
		XCTAssertEqual(viewModel.username, expectedUsername, "Expected username to be published and observable")
		XCTAssertEqual(viewModel.password, expectedPassword, "Expected password to be published and observable")
	}
	
	func test_onSuccessAlertDismissed_executesCallback() async {
		let viewModel = LoginViewModel(authenticate: { _, _ in .success(LoginResponse(token: "token")) })
		_ = await LoginView(viewModel: viewModel)
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
}
