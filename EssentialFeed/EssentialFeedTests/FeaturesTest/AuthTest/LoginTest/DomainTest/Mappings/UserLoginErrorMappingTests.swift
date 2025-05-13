import EssentialFeed
import XCTest

// CU: Autenticación de Usuario
// Checklist: Mapping de errores a mensajes claros y específicos para el usuario final
final class UserLoginErrorMappingTests: XCTestCase {
    func test_errorMapping_returnsCorrectMessageForEachError() {
        // Given
        let cases: [(LoginError, String)] = [
            (.invalidEmailFormat, "Email format is invalid."),
            (.invalidPasswordFormat, "Password cannot be empty."),
            (.invalidCredentials, "Invalid credentials."),
            (.network, "Could not connect. Please try again."),
            (.unknown, "Something went wrong. Please try again.")
        ]

        for (error, expectedMessage) in cases {
            XCTAssertEqual(LoginErrorMessageMapper.message(for: error), expectedMessage, "Error mapping for \(error) should be '\(expectedMessage)'")
        }
    }
}
