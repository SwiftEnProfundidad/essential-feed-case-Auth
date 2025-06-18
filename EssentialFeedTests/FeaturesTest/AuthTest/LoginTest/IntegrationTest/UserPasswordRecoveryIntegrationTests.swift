import EssentialFeed
import XCTest

final class UserPasswordRecoveryIntegrationTests: XCTestCase {
    func test_recovery_succeeds_withValidEmail_andNotifiesSuccess() {
        let (sut, _, _, tokenManager, auditLogger) = makeSUT()
        let validEmail = "user@example.com"
        let resetToken = PasswordResetToken(token: "reset-123", email: validEmail, expirationDate: Date().addingTimeInterval(900))
        tokenManager.stubbedGeneratedToken = resetToken
        var receivedResponse: PasswordRecoveryResponse?
        let expectation = expectation(description: "Wait for completion")

        sut.recoverPassword(email: validEmail, ipAddress: "192.168.1.1", userAgent: "TestAgent/1.0") { result in
            if case let .success(response) = result {
                receivedResponse = response
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(tokenManager.generateResetTokenCallCount, 1, "Expected generateResetToken to be called once")
        XCTAssertEqual(receivedResponse?.message, "Password reset link sent to your email", "Expected success message")
        XCTAssertEqual(receivedResponse?.resetToken, "reset-123", "Expected reset token to match")
        XCTAssertEqual(auditLogger.logRecoveryAttemptCallCount, 1, "Expected audit log to be called once")
        XCTAssertEqual(auditLogger.loggedAuditLogs.first?.outcome, .success, "Expected success outcome in audit log")
    }

    func test_recovery_fails_withInvalidEmailFormat_andDoesNotGenerateToken() {
        let (sut, _, _, tokenManager, auditLogger) = makeSUT()
        let invalidEmail = "invalid-email-format"
        var receivedError: PasswordRecoveryError?
        let expectation = expectation(description: "Wait for completion")

        sut.recoverPassword(email: invalidEmail, ipAddress: "192.168.1.1", userAgent: "TestAgent/1.0") { result in
            if case let .failure(error) = result {
                receivedError = error
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(tokenManager.generateResetTokenCallCount, 0, "Expected no token generation for invalid email")
        XCTAssertEqual(receivedError, PasswordRecoveryError.invalidEmailFormat, "Expected invalid email format error")
        XCTAssertEqual(auditLogger.logRecoveryAttemptCallCount, 1, "Expected audit log to be called once")
        XCTAssertEqual(auditLogger.loggedAuditLogs.first?.outcome, .invalidEmailFormat, "Expected invalid email outcome in audit log")
    }

    func test_recovery_fails_whenTokenGenerationFails_andNotifiesFailure() {
        let (sut, _, _, tokenManager, auditLogger) = makeSUT()
        let validEmail = "user@example.com"
        tokenManager.shouldThrowOnGenerate = true
        var receivedError: PasswordRecoveryError?
        let expectation = expectation(description: "Wait for completion")

        sut.recoverPassword(email: validEmail, ipAddress: "192.168.1.1", userAgent: "TestAgent/1.0") { result in
            if case let .failure(error) = result {
                receivedError = error
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(tokenManager.generateResetTokenCallCount, 1, "Expected generateResetToken to be called")
        XCTAssertEqual(receivedError, PasswordRecoveryError.tokenGenerationFailed, "Expected token generation failed error")
        XCTAssertEqual(auditLogger.logRecoveryAttemptCallCount, 1, "Expected audit log to be called once")
        XCTAssertEqual(auditLogger.loggedAuditLogs.first?.outcome, .tokenGenerationFailed, "Expected token generation failed outcome in audit log")
    }

    func test_recovery_fails_whenRateLimitExceeded_andDoesNotGenerateToken() {
        let (sut, _, rateLimiter, tokenManager, auditLogger) = makeSUTWithRateLimit()
        rateLimiter.stubbedValidationResult = Result<Void, PasswordRecoveryError>.failure(PasswordRecoveryError.rateLimitExceeded(retryAfterSeconds: 300))
        let validEmail = "user@example.com"
        var receivedError: PasswordRecoveryError?
        let expectation = expectation(description: "Wait for completion")

        sut.recoverPassword(email: validEmail, ipAddress: "192.168.1.1", userAgent: "TestAgent/1.0") { result in
            if case let .failure(error) = result {
                receivedError = error
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(tokenManager.generateResetTokenCallCount, 0, "Expected no token generation when rate limited")
        if case let .rateLimitExceeded(retryAfterSeconds) = receivedError {
            XCTAssertEqual(retryAfterSeconds, 300, "Expected retry after seconds to match")
        } else {
            XCTFail("Expected rateLimitExceeded error, got \(String(describing: receivedError))")
        }
        XCTAssertEqual(auditLogger.logRecoveryAttemptCallCount, 1, "Expected audit log to be called once")
        XCTAssertEqual(auditLogger.loggedAuditLogs.first?.outcome, .rateLimitExceeded, "Expected rate limit exceeded outcome in audit log")
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: UserPasswordRecoveryUseCase, apiSpy: PasswordRecoveryAPISpy, rateLimiterSpy: PasswordRecoveryRateLimiterSpy, tokenManagerSpy: PasswordResetTokenManagerSpy, auditLoggerSpy: PasswordRecoveryAuditLoggerSpy) {
        let apiSpy = PasswordRecoveryAPISpy()
        let rateLimiterSpy = PasswordRecoveryRateLimiterSpy()
        let tokenManagerSpy = PasswordResetTokenManagerSpy()
        let auditLoggerSpy = PasswordRecoveryAuditLoggerSpy()
        let sut = RemoteUserPasswordRecoveryUseCase(api: apiSpy, rateLimiter: rateLimiterSpy, tokenManager: tokenManagerSpy, auditLogger: auditLoggerSpy)
        trackForMemoryLeaks(apiSpy, file: file, line: line)
        trackForMemoryLeaks(rateLimiterSpy, file: file, line: line)
        trackForMemoryLeaks(tokenManagerSpy, file: file, line: line)
        trackForMemoryLeaks(auditLoggerSpy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, apiSpy, rateLimiterSpy, tokenManagerSpy, auditLoggerSpy)
    }

    private func makeSUTWithRateLimit(file: StaticString = #filePath, line: UInt = #line) -> (sut: UserPasswordRecoveryUseCase, apiSpy: PasswordRecoveryAPISpy, rateLimiterSpy: PasswordRecoveryRateLimiterSpy, tokenManagerSpy: PasswordResetTokenManagerSpy, auditLoggerSpy: PasswordRecoveryAuditLoggerSpy) {
        makeSUT(file: file, line: line)
    }
}
