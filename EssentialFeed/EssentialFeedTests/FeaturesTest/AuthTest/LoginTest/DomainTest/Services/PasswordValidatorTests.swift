import EssentialFeed
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

    func test_validate_failsWithMissingUppercaseLetter_whenNoUppercase() {
        let sut = DefaultPasswordValidator()
        let passwordWithoutUppercase = "nouppercase1!"
        let expectedError = PasswordValidationError.missingUppercaseLetter

        let result = sut.validate(password: passwordWithoutUppercase)

        switch result {
        case .success:
            XCTFail("Validation should have failed with error \(expectedError), but succeeded instead.")
        case let .failure(receivedError):
            XCTAssertEqual(receivedError, expectedError, "Expected error to be \(expectedError), but got \(receivedError) instead.")
        }
    }

    func test_validate_failsWithMissingNumber_whenNoNumber() {
        let sut = DefaultPasswordValidator()
        let passwordWithoutNumber = "NoNumber!"
        let expectedError = PasswordValidationError.missingNumber

        let result = sut.validate(password: passwordWithoutNumber)

        switch result {
        case .success:
            XCTFail("Validation should have failed with error \(expectedError), but succeeded instead.")
        case let .failure(receivedError):
            XCTAssertEqual(receivedError, expectedError, "Expected error to be \(expectedError), but got \(receivedError) instead.")
        }
    }

    func test_validate_failsWithMissingSpecialCharacter_whenNoSpecialCharacter() {
        let sut = DefaultPasswordValidator()
        let passwordWithoutSpecialChar = "NoSpecial1"
        let expectedError = PasswordValidationError.missingSpecialCharacter

        let result = sut.validate(password: passwordWithoutSpecialChar)

        switch result {
        case .success:
            XCTFail("Validation should have failed with error \(expectedError), but succeeded instead.")
        case let .failure(receivedError):
            XCTAssertEqual(receivedError, expectedError, "Expected error to be \(expectedError), but got \(receivedError) instead.")
        }
    }

    func test_validate_succeeds_forValidPassword() {
        let sut = DefaultPasswordValidator()
        let validPassword = "ValidPassword1!"

        let result = sut.validate(password: validPassword)

        switch result {
        case .success:
            // Success case, do nothing.
            break
        case let .failure(error):
            XCTFail("Validation should have succeeded, but failed with error \(error).")
        }
    }
}
