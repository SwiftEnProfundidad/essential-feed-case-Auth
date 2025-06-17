import EssentialFeed
import XCTest

final class UserPasswordRecoveryIntegrationTests: XCTestCase {
    func test_recovery_succeeds_withValidEmail_andNotifiesSuccess() {
        let (sut, _, _, tokenManager) = makeSUT()
        let validEmail = "user@example.com"
        let resetToken = PasswordResetToken(token: "reset-123", email: validEmail, expirationDate: Date().addingTimeInterval(900))
        tokenManager.stubbedGeneratedToken = resetToken
        var receivedResponse: PasswordRecoveryResponse?

        sut.recoverPassword(email: validEmail) { result in
            if case let .success(response) = result {
                receivedResponse = response
            }
        }

        XCTAssertEqual(tokenManager.generateResetTokenCallCount, 1, "Expected generateResetToken to be called once")
        XCTAssertEqual(receivedResponse?.message, "Password reset link sent to your email", "Expected success message")
        XCTAssertEqual(receivedResponse?.resetToken, "reset-123", "Expected reset token to match")
    }

    func test_recovery_fails_withInvalidEmailFormat_andDoesNotGenerateToken() {
        let (sut, _, _, tokenManager) = makeSUT()
        let invalidEmail = "invalid-email-format"
        var receivedError: PasswordRecoveryError?

        sut.recoverPassword(email: invalidEmail) { result in
            if case let .failure(error) = result {
                receivedError = error
            }
        }

        XCTAssertEqual(tokenManager.generateResetTokenCallCount, 0, "Expected no token generation for invalid email")
        XCTAssertEqual(receivedError, PasswordRecoveryError.invalidEmailFormat, "Expected invalid email format error")
    }

    func test_recovery_fails_whenTokenGenerationFails_andNotifiesFailure() {
        let (sut, _, _, tokenManager) = makeSUT()
        let validEmail = "user@example.com"
        tokenManager.shouldThrowOnGenerate = true
        var receivedError: PasswordRecoveryError?

        sut.recoverPassword(email: validEmail) { result in
            if case let .failure(error) = result {
                receivedError = error
            }
        }

        XCTAssertEqual(tokenManager.generateResetTokenCallCount, 1, "Expected generateResetToken to be called")
        XCTAssertEqual(receivedError, PasswordRecoveryError.tokenGenerationFailed, "Expected token generation failed error")
    }

    func test_recovery_fails_whenRateLimitExceeded_andDoesNotGenerateToken() {
        let (sut, _, rateLimiter, tokenManager) = makeSUTWithRateLimit()
        rateLimiter.stubbedValidationResult = Result<Void, PasswordRecoveryError>.failure(PasswordRecoveryError.rateLimitExceeded(retryAfterSeconds: 300))
        let validEmail = "user@example.com"
        var receivedError: PasswordRecoveryError?

        sut.recoverPassword(email: validEmail) { result in
            if case let .failure(error) = result {
                receivedError = error
            }
        }

        XCTAssertEqual(tokenManager.generateResetTokenCallCount, 0, "Expected no token generation when rate limited")
        if case let .rateLimitExceeded(retryAfterSeconds) = receivedError {
            XCTAssertEqual(retryAfterSeconds, 300, "Expected retry after seconds to match")
        } else {
            XCTFail("Expected rateLimitExceeded error, got \(String(describing: receivedError))")
        }
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: UserPasswordRecoveryUseCase, apiSpy: PasswordRecoveryAPISpy, rateLimiterSpy: PasswordRecoveryRateLimiterSpy, tokenManagerSpy: PasswordResetTokenManagerSpy) {
        let apiSpy = PasswordRecoveryAPISpy()
        let rateLimiterSpy = PasswordRecoveryRateLimiterSpy()
        let tokenManagerSpy = PasswordResetTokenManagerSpy()
        let sut = RemoteUserPasswordRecoveryUseCase(api: apiSpy, rateLimiter: rateLimiterSpy, tokenManager: tokenManagerSpy)
        trackForMemoryLeaks(apiSpy, file: file, line: line)
        trackForMemoryLeaks(rateLimiterSpy, file: file, line: line)
        trackForMemoryLeaks(tokenManagerSpy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, apiSpy, rateLimiterSpy, tokenManagerSpy)
    }

    private func makeSUTWithRateLimit(file: StaticString = #filePath, line: UInt = #line) -> (sut: UserPasswordRecoveryUseCase, apiSpy: PasswordRecoveryAPISpy, rateLimiterSpy: PasswordRecoveryRateLimiterSpy, tokenManagerSpy: PasswordResetTokenManagerSpy) {
        makeSUT(file: file, line: line)
    }
}
