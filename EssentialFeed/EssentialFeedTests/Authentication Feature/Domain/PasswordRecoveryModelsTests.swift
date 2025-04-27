import XCTest
import EssentialFeed

final class PasswordRecoveryModelsTests: XCTestCase {
    func test_init_setsEmail() {
        let email = "test@example.com"
        let sut = PasswordRecoveryRequest(email: email)
        XCTAssertEqual(sut.email, email)
    }

    func test_init_setsMessage() {
        let message = "Mensaje de prueba"
        let sut = PasswordRecoveryResponse(message: message)
        XCTAssertEqual(sut.message, message)
    }
}
