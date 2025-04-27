import XCTest
import EssentialFeed

final class PasswordRecoveryModelsTests: XCTestCase {
    
    func test_init_setsEmail() {
        let email = "test@example.com"
        let sut = makeRequest(email: email)
        XCTAssertEqual(sut.email, email)
    }

    func test_init_setsMessage() {
        let message = "Mensaje de prueba"
        let sut = makeResponse(message: message)
        XCTAssertEqual(sut.message, message)
    }

    // MARK: - Helpers
    private func makeRequest(email: String) -> PasswordRecoveryRequest {
        PasswordRecoveryRequest(email: email)
    }
    private func makeResponse(message: String) -> PasswordRecoveryResponse {
        PasswordRecoveryResponse(message: message)
    }
}
