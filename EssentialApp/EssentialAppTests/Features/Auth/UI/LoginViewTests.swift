import Combine
import EssentialApp
import EssentialFeed
import SwiftUI
import UIKit
import XCTest

final class LoginViewTests: XCTestCase {
    func test_login_withInvalidEmail_showsValidationError() async {
        let (sut, _) = makeSUT(authenticateResult: .failure(.invalidEmailFormat))
        sut.username = "invalid-email"
        sut.password = "password"

        await sut.login()
        XCTAssertEqual(sut.currentNotification?.message, "Invalid username or password.")
    }

    func test_login_withEmptyPassword_showsValidationError() async {
        let (sut, _) = makeSUT(authenticateResult: .failure(.invalidPasswordFormat))
        sut.username = "user@email.com"
        sut.password = ""
        await sut.login()
        XCTAssertEqual(sut.currentNotification?.message, "Please enter both username and password")
    }

    func test_login_withValidCredentials_triggersAuthentication() async {
        let exp = expectation(description: "Authentication triggered")
        let (sut, _) = makeSUT(
            authenticateResult: .success(makeSuccessfulLoginResponse()),
            onAuthenticate: { username, password in
                XCTAssertEqual(username, "user@email.com")
                XCTAssertEqual(password, "password")
                exp.fulfill()
            }
        )
        sut.username = "user@email.com"
        sut.password = "password"
        await sut.login()
        await fulfillment(of: [exp], timeout: 1.0)
    }

    func test_login_success_showsSuccessFeedback() async {
        let (sut, _) = makeSUT(authenticateResult: .success(makeSuccessfulLoginResponse()))
        sut.username = "user@email.com"
        sut.password = "password"
        await sut.login()
        XCTAssertTrue(sut.loginSuccess, "Expected loginSuccess to be true after successful login")
        XCTAssertNil(sut.errorMessage, "Expected errorMessage to be nil after successful login")
        XCTAssertFalse(sut.isLoginBlocked, "Expected isLoginBlocked to be false after successful login")
        XCTAssertEqual(sut.currentNotification?.type, .success)
    }

    func test_login_withInvalidCredentials_showsAuthenticationError() async {
        let (sut, _) = makeSUT(authenticateResult: .failure(.invalidCredentials))
        sut.username = "user@email.com"
        sut.password = "wrongpass"
        await sut.login()
        XCTAssertEqual(sut.currentNotification?.message, "Invalid username or password.")
    }

    // MARK: - Helpers

    private func makeSUT(
        authenticateResult: Result<LoginResponse, LoginError> = .failure(.invalidCredentials),
        onAuthenticate: ((String, String) -> Void)? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) -> (LoginViewModel, AuthSpy) {
        let authSpy = AuthSpy(result: authenticateResult, onAuthenticate: onAuthenticate)
        let loginSecurity = LoginSecurityUseCase(
            store: FailedLoginAttemptsStoreSpy(),
            configuration: .init(maxAttempts: 3, blockDuration: 300, captchaThreshold: 2)
        )
        let sut = LoginViewModel(
            authenticate: authSpy.authenticate,
            pendingRequestStore: nil,
            loginSecurity: loginSecurity
        )
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(authSpy, file: file, line: line)
        trackForMemoryLeaks(loginSecurity, file: file, line: line)
        return (sut, authSpy)
    }

    private func makeSuccessfulLoginResponse() -> LoginResponse {
        return LoginResponse(
            user: User(name: "Test User", email: "user@email.com"),
            token: Token(
                accessToken: "token", expiry: Date().addingTimeInterval(3600), refreshToken: nil
            )
        )
    }

    private class AuthSpy {
        private let result: Result<LoginResponse, LoginError>
        private let onAuthenticate: ((String, String) -> Void)?

        init(result: Result<LoginResponse, LoginError>, onAuthenticate: ((String, String) -> Void)? = nil) {
            self.result = result
            self.onAuthenticate = onAuthenticate
        }

        func authenticate(username: String, password: String) async -> Result<LoginResponse, LoginError> {
            onAuthenticate?(username, password)
            return result
        }
    }
}
