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

    func test_register_onFailure_doesNotTriggerNavigation() async {
        let userRegistererSpy = UserRegistererSpy()
        let networkError = NSError(domain: "NetworkError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Network connection failed"])
        userRegistererSpy.result = .failure(networkError)
        let navigationSpy = RegistrationNavigationSpy()
        let sut = makeSUT(userRegisterer: userRegistererSpy)
        sut.navigation = navigationSpy

        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        await sut.register()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(navigationSpy.showLoginCallCount, 0, "Should not trigger navigation on registration failure")
        XCTAssertEqual(navigationSpy.showMainAppCallCount, 0, "Should not trigger auto-login on registration failure")
    }

    func test_register_onSuccess_triggersAutoLoginToMainApp() async {
        let userRegistererSpy = UserRegistererSpy()
        let testUser = User(name: "Test User", email: "test@example.com")
        userRegistererSpy.result = .success(TokenAndUser(token: Token(accessToken: "token123", expiry: Date(), refreshToken: nil), user: testUser))
        let navigationSpy = RegistrationNavigationSpy()
        let sut = makeSUT(userRegisterer: userRegistererSpy)
        sut.navigation = navigationSpy

        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        await sut.register()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(navigationSpy.showMainAppCallCount, 1, "Should trigger auto-login to main app after successful registration")
        XCTAssertEqual(navigationSpy.showLoginCallCount, 0, "Should not trigger showLogin in auto-login flow")
        XCTAssertEqual(navigationSpy.receivedUser?.name, "Test User", "Should pass correct user for auto-login")
        XCTAssertEqual(navigationSpy.receivedUser?.email, "test@example.com", "Should pass correct user email for auto-login")
    }

    func test_register_onFailure_doesNotTriggerAutoLogin() async {
        let userRegistererSpy = UserRegistererSpy()
        let networkError = NSError(domain: "NetworkError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Network connection failed"])
        userRegistererSpy.result = .failure(networkError)
        let navigationSpy = RegistrationNavigationSpy()
        let sut = makeSUT(userRegisterer: userRegistererSpy)
        sut.navigation = navigationSpy

        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        await sut.register()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(navigationSpy.showMainAppCallCount, 0, "Should not trigger auto-login on registration failure")
        XCTAssertNil(navigationSpy.receivedUser, "Should not pass user data on failure")
    }

    // MARK: - Error Handling Tests

    func test_register_onEmailAlreadyInUseError_showsUserFriendlyMessage() async {
        let userRegistererSpy = UserRegistererSpy()
        let emailInUseError = UserRegistrationError.emailAlreadyInUse
        userRegistererSpy.result = .failure(emailInUseError)
        let sut = makeSUT(userRegisterer: userRegistererSpy)

        sut.email = "existing@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        await sut.register()

        XCTAssertEqual(sut.errorMessage, "This email is already registered. Please use a different email or try logging in.", "Should show user-friendly email already in use message")
        XCTAssertFalse(sut.registrationSuccess, "Registration should fail")
        XCTAssertEqual(sut.email, "existing@example.com", "Email should not be cleared on failure")
    }

    func test_register_onConnectivityError_showsUserFriendlyNetworkMessage() async {
        let userRegistererSpy = UserRegistererSpy()
        let connectivityError = NetworkError.noConnectivity
        userRegistererSpy.result = .failure(connectivityError)
        let sut = makeSUT(userRegisterer: userRegistererSpy)

        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        await sut.register()

        XCTAssertEqual(sut.errorMessage, "No internet connection. Please check your network and try again.", "Should show user-friendly connectivity error message")
        XCTAssertFalse(sut.registrationSuccess, "Registration should fail")
    }

    func test_register_onServerError_showsUserFriendlyServerMessage() async {
        let userRegistererSpy = UserRegistererSpy()
        let serverError = NetworkError.serverError(statusCode: 500)
        userRegistererSpy.result = .failure(serverError)
        let sut = makeSUT(userRegisterer: userRegistererSpy)

        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        await sut.register()

        XCTAssertEqual(sut.errorMessage, "Server error (500). Please try again later.", "Should show user-friendly server error message")
        XCTAssertFalse(sut.registrationSuccess, "Registration should fail")
    }

    func test_register_onClientError_showsUserFriendlyClientMessage() async {
        let userRegistererSpy = UserRegistererSpy()
        let clientError = NetworkError.clientError(statusCode: 400)
        userRegistererSpy.result = .failure(clientError)
        let sut = makeSUT(userRegisterer: userRegistererSpy)

        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        await sut.register()

        XCTAssertEqual(sut.errorMessage, "Request error (400). Please check your information and try again.", "Should show user-friendly client error message")
        XCTAssertFalse(sut.registrationSuccess, "Registration should fail")
    }

    func test_register_onInvalidDataError_showsUserFriendlyValidationMessage() async {
        let userRegistererSpy = UserRegistererSpy()
        let invalidDataError = UserRegistrationError.invalidData
        userRegistererSpy.result = .failure(invalidDataError)
        let sut = makeSUT(userRegisterer: userRegistererSpy)

        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        await sut.register()

        XCTAssertEqual(sut.errorMessage, "The registration data is invalid. Please check your information and try again.", "Should show user-friendly invalid data error message")
        XCTAssertFalse(sut.registrationSuccess, "Registration should fail")
    }

    func test_register_onReplayAttackDetected_showsUserFriendlySecurityMessage() async {
        let userRegistererSpy = UserRegistererSpy()
        let replayAttackError = UserRegistrationError.replayAttackDetected
        userRegistererSpy.result = .failure(replayAttackError)
        let sut = makeSUT(userRegisterer: userRegistererSpy)

        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        await sut.register()

        XCTAssertEqual(sut.errorMessage, "Security validation failed. Please try again.", "Should show user-friendly replay attack error message")
        XCTAssertFalse(sut.registrationSuccess, "Registration should fail")
    }

    func test_register_onAbuseDetected_showsUserFriendlyAbuseMessage() async {
        let userRegistererSpy = UserRegistererSpy()
        let abuseError = UserRegistrationError.abuseDetected
        userRegistererSpy.result = .failure(abuseError)
        let sut = makeSUT(userRegisterer: userRegistererSpy)

        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        await sut.register()

        XCTAssertEqual(sut.errorMessage, "Too many registration attempts detected. Please try again later.", "Should show user-friendly abuse detected error message")
        XCTAssertFalse(sut.registrationSuccess, "Registration should fail")
    }

    func test_register_onTokenStorageFailed_showsUserFriendlyStorageMessage() async {
        let userRegistererSpy = UserRegistererSpy()
        let storageError = UserRegistrationError.tokenStorageFailed
        userRegistererSpy.result = .failure(storageError)
        let sut = makeSUT(userRegisterer: userRegistererSpy)

        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        await sut.register()

        XCTAssertEqual(sut.errorMessage, "Failed to save authentication data. Please try again.", "Should show user-friendly token storage error message")
        XCTAssertFalse(sut.registrationSuccess, "Registration should fail")
    }

    func test_register_onUnknownError_showsUserFriendlyGenericMessage() async {
        let userRegistererSpy = UserRegistererSpy()
        let unknownError = UserRegistrationError.unknown
        userRegistererSpy.result = .failure(unknownError)
        let sut = makeSUT(userRegisterer: userRegistererSpy)

        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        await sut.register()

        XCTAssertEqual(sut.errorMessage, "An unexpected error occurred. Please try again.", "Should show user-friendly unknown error message")
        XCTAssertFalse(sut.registrationSuccess, "Registration should fail")
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

private final class RegistrationNavigationSpy: RegistrationNavigation {
    private(set) var showLoginCallCount = 0
    private(set) var showMainAppCallCount = 0
    private(set) var receivedUser: User?

    func showLogin() {
        showLoginCallCount += 1
    }

    func showMainApp(for user: User) {
        showMainAppCallCount += 1
        receivedUser = user
    }
}
