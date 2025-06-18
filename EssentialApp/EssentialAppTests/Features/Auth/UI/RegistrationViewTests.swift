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

    func test_register_callsUserRegistrationUseCaseWithCorrectData() async {
        let userRegistererSpy = UserRegistererSpy()
        let sut = makeSUT(userRegisterer: userRegistererSpy)

        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        await sut.register()

        XCTAssertEqual(userRegistererSpy.registerCallCount, 1, "Should call register once")
        XCTAssertEqual(userRegistererSpy.receivedName, "", "Should pass empty name")
        XCTAssertEqual(userRegistererSpy.receivedEmail, "test@example.com", "Should pass correct email")
        XCTAssertEqual(userRegistererSpy.receivedPassword, "password123", "Should pass correct password")
    }

    func test_register_onSuccess_clearsFieldsAndShowsSuccessState() async {
        let userRegistererSpy = UserRegistererSpy()
        userRegistererSpy.result = .success(TokenAndUser(token: Token(accessToken: "token123", expiry: Date(), refreshToken: nil), user: User(name: "Test", email: "test@example.com")))
        let sut = makeSUT(userRegisterer: userRegistererSpy)

        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        await sut.register()

        XCTAssertEqual(sut.email, "", "Email should be cleared after successful registration")
        XCTAssertEqual(sut.password, "", "Password should be cleared after successful registration")
        XCTAssertEqual(sut.confirmPassword, "", "Confirm password should be cleared after successful registration")
        XCTAssertNil(sut.errorMessage, "Error message should be nil after successful registration")
        XCTAssertFalse(sut.isLoading, "Loading should be false after registration completes")
        XCTAssertTrue(sut.registrationSuccess, "Registration success flag should be true")
    }

    func test_register_onFailure_showsSpecificErrorMessage() async {
        let userRegistererSpy = UserRegistererSpy()
        let networkError = NSError(domain: "NetworkError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Network connection failed"])
        userRegistererSpy.result = .failure(networkError)
        let sut = makeSUT(userRegisterer: userRegistererSpy)

        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        await sut.register()

        XCTAssertEqual(sut.errorMessage, "Network connection failed", "Should show specific error message from registration failure")
        XCTAssertFalse(sut.registrationSuccess, "Registration success flag should be false on failure")
        XCTAssertFalse(sut.isLoading, "Loading should be false after registration completes")
        XCTAssertEqual(sut.email, "test@example.com", "Email should not be cleared on failure")
        XCTAssertEqual(sut.password, "password123", "Password should not be cleared on failure")
        XCTAssertEqual(sut.confirmPassword, "password123", "Confirm password should not be cleared on failure")
    }

    // MARK: - Helpers

    private func makeSUT(
        userRegisterer: UserRegisterer = UserRegistererSpy(),
        file: StaticString = #file,
        line: UInt = #line
    ) -> RegistrationViewModel {
        let sut = RegistrationViewModel(userRegisterer: userRegisterer)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(userRegisterer, file: file, line: line)
        return sut
    }
}

private final class UserRegistererSpy: UserRegisterer {
    private(set) var registerCallCount = 0
    private(set) var receivedName = ""
    private(set) var receivedEmail = ""
    private(set) var receivedPassword = ""
    var result: UserRegistrationResult = .failure(NSError(domain: "TestError", code: 0, userInfo: nil))

    func register(name: String, email: String, password: String) async -> UserRegistrationResult {
        registerCallCount += 1
        receivedName = name
        receivedEmail = email
        receivedPassword = password
        return result
    }
}
