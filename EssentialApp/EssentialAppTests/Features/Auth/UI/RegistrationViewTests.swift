import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

final class RegistrationViewTests: XCTestCase {
    func test_registrationViewModel_initialState() {
        let sut = makeSUT()

        XCTAssertEqual(sut.email, "", "Email should be empty initially")
        XCTAssertEqual(sut.password, "", "Password should be empty initially")
        XCTAssertEqual(sut.confirmPassword, "", "Confirm password should be empty initially")
        XCTAssertNil(sut.errorMessage, "Error message should be nil initially")
        XCTAssertFalse(sut.isLoading, "Loading should be false initially")
    }

    func test_registrationViewModel_emailValidation_withEmptyEmail_setsError() async {
        let sut = makeSUT()
        sut.email = ""
        sut.password = "validpass123"
        sut.confirmPassword = "validpass123"

        await sut.register()

        XCTAssertEqual(sut.errorMessage, "Email cannot be empty", "Should show email validation error")
    }

    func test_registrationViewModel_passwordValidation_withEmptyPassword_setsError() async {
        let sut = makeSUT()
        sut.email = "test@example.com"
        sut.password = ""
        sut.confirmPassword = ""

        await sut.register()

        XCTAssertEqual(sut.errorMessage, "Password cannot be empty", "Should show password validation error")
    }

    func test_registrationViewModel_passwordMatch_withMismatchedPasswords_setsError() async {
        let sut = makeSUT()
        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "different123"

        await sut.register()

        XCTAssertEqual(sut.errorMessage, "Passwords do not match", "Should show password mismatch error")
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #file,
        line: UInt = #line
    ) -> RegistrationViewModel {
        let sut = RegistrationViewModel()
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
}
