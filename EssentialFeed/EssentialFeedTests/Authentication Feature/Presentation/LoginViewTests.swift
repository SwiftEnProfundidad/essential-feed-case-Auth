import XCTest
import SwiftUI
import EssentialApp

final class LoginViewTests: XCTestCase {
    func test_login_withInvalidEmail_showsValidationError() {
        // Arrange
        let viewModel = LoginViewModel(authenticate: { _, _ in .failure(.invalidCredentials) })
        let sut = LoginView(viewModel: viewModel)
        viewModel.username = "invalid-email"
        viewModel.password = "password"
        // Act
        viewModel.login()
        // Assert
        XCTAssertEqual(viewModel.errorMessage, "El email introducido no es válido.")
    }

    func test_login_withEmptyPassword_showsValidationError() {
        let viewModel = LoginViewModel(authenticate: { _, _ in .failure(.invalidCredentials) })
        let sut = LoginView(viewModel: viewModel)
        viewModel.username = "user@email.com"
        viewModel.password = ""
        viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "La contraseña no puede estar vacía.")
    }

    func test_login_withValidCredentials_triggersAuthentication() {
        let exp = expectation(description: "Authentication triggered")
        let viewModel = LoginViewModel(authenticate: { username, password in
            XCTAssertEqual(username, "user@email.com")
            XCTAssertEqual(password, "password")
            exp.fulfill()
            return .success(LoginResponse(token: "token"))
        })
        let sut = LoginView(viewModel: viewModel)
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        viewModel.login()
        wait(for: [exp], timeout: 1.0)
    }

    func test_login_withInvalidCredentials_showsAuthenticationError() {
        let viewModel = LoginViewModel(authenticate: { _, _ in .failure(.invalidCredentials) })
        let sut = LoginView(viewModel: viewModel)
        viewModel.username = "user@email.com"
        viewModel.password = "wrongpass"
        viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "Credenciales incorrectas.")
    }

    func test_login_success_showsSuccessFeedback() {
        let viewModel = LoginViewModel(authenticate: { _, _ in .success(LoginResponse(token: "token")) })
        let sut = LoginView(viewModel: viewModel)
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        viewModel.login()
        XCTAssertTrue(viewModel.loginSuccess)
    }

    func test_login_error_showsErrorFeedback() {
        let viewModel = LoginViewModel(authenticate: { _, _ in .failure(.unknown) })
        let sut = LoginView(viewModel: viewModel)
        viewModel.username = "user@email.com"
        viewModel.password = "password"
        viewModel.login()
        XCTAssertEqual(viewModel.errorMessage, "Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo más tarde.")
    }
}
