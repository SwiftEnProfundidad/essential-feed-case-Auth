@testable import EssentialFeed
import XCTest

final class PasswordValidatorTests: XCTestCase {
    func test_validate_failsWithTooShortError_whenPasswordIsLessThan8Characters() {
        let sut = DefaultPasswordValidator()
        let shortPassword = "Short1!"
        let expectedError = PasswordValidationError.tooShort

        let result = sut.validate(password: shortPassword)

        switch result {
        case .success:
            XCTFail("Validation should have failed with error \(expectedError), but succeeded instead.")
        case let .failure(receivedError):
            XCTAssertEqual(receivedError, expectedError, "Expected error to be \(expectedError), but got \(receivedError) instead.")
        }
    }
}
