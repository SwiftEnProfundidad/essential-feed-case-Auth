import XCTest

// CU: Login
// Checklist:
// - [x] Muestra alerta de éxito al login correcto con mensaje personalizado.
// - [x] Muestra alerta de error al login fallido con mensaje adecuado.
// - [x] Permite acceder a la pantalla de recuperación de contraseña desde el login.
// - [x] Los campos de usuario y contraseña son accesibles y editables.
// - [x] El botón de login está habilitado cuando los campos están completos.
// - [x] El flujo de recuperación muestra el campo de email.

final class LoginView_UITests: XCTestCase {
	func test_loginSuccess_showsSuccessNotification() {
		let app = XCUIApplication()
		app.launch()
		
		let username = "user"
		let password = "pass"
		
		let usernameField = app.textFields["Username"]
		XCTAssertTrue(usernameField.exists)
		usernameField.tap()
		usernameField.typeText(username)
		
		let passwordField = app.secureTextFields["Password"]
		XCTAssertTrue(passwordField.exists)
		passwordField.tap()
		passwordField.typeText(password)
		
		let loginButton = app.buttons["Login"]
		XCTAssertTrue(loginButton.exists)
		loginButton.tap()
		
		let successAlert = app.alerts["Login Successful"]
		XCTAssertTrue(successAlert.waitForExistence(timeout: 2))
		let expectedMessage = "Welcome, \(username)!"
		XCTAssertTrue(successAlert.staticTexts[expectedMessage].exists)
		successAlert.buttons["OK"].tap()
	}
	
	func test_loginFailure_showsErrorAlert() {
		let app = XCUIApplication()
		app.launch()
		
		let username = "user"
		let password = "wrongpass"
		
		let usernameField = app.textFields["Username"]
		XCTAssertTrue(usernameField.exists)
		usernameField.tap()
		usernameField.typeText(username)
		
		let passwordField = app.secureTextFields["Password"]
		XCTAssertTrue(passwordField.exists)
		passwordField.tap()
		passwordField.typeText(password)
		
		let loginButton = app.buttons["Login"]
		XCTAssertTrue(loginButton.exists)
		loginButton.tap()
		
		let errorAlert = app.alerts["Login Failed"]
		XCTAssertTrue(errorAlert.waitForExistence(timeout: 2))
		XCTAssertTrue(errorAlert.staticTexts["Invalid credentials"].exists)
		errorAlert.buttons["OK"].tap()
	}
	
	func test_tapForgotPassword_showsRecoveryScreen() {
		let app = XCUIApplication()
		app.launch()
		
		let forgotPasswordButton = app.buttons["Forgot your password?"]
		XCTAssertTrue(forgotPasswordButton.exists)
		forgotPasswordButton.tap()
		
		// Ajusta según el identificador/título real de la pantalla de recuperación
		let recoveryTitle = app.staticTexts["Email"]  // Primer campo visible
		XCTAssertTrue(recoveryTitle.waitForExistence(timeout: 2))
	}
}
