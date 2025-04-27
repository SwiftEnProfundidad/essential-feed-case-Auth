import XCTest

final class LoginView_UITests: XCTestCase {
	func test_loginSuccess_showsSuccessNotification() {
		let app = XCUIApplication()
		app.launch()
		
		// Rellena el campo de usuario
		let usernameField = app.textFields["Username"]
		XCTAssertTrue(usernameField.exists)
		usernameField.tap()
		usernameField.typeText("user")
		
		// Rellena el campo de contraseña
		let passwordField = app.secureTextFields["Password"]
		XCTAssertTrue(passwordField.exists)
		passwordField.tap()
		passwordField.typeText("pass")
		
		// Pulsa el botón de login
		let loginButton = app.buttons["Login"]
		XCTAssertTrue(loginButton.exists)
		loginButton.tap()
		
		// Verifica que aparece la alerta de éxito
		let successAlert = app.alerts["Login Successful"]
		XCTAssertTrue(successAlert.waitForExistence(timeout: 2))
		XCTAssertTrue(successAlert.staticTexts["Welcome!"].exists)
		
		// Pulsa OK para cerrar la alerta
		successAlert.buttons["OK"].tap()
	}
}
