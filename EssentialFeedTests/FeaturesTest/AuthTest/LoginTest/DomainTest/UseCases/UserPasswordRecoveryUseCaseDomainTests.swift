import EssentialFeed
import XCTest

final class UserPasswordRecoveryUseCaseDomainTests: XCTestCase {
    func test_recoverPassword_deliversSuccessWithResetToken_onValidEmailWithinRateLimit() {
        let (sut, _, _, tokenManager, _) = makeSUT()
        let resetToken = PasswordResetToken(token: "reset-token-123", email: "test@example.com", expirationDate: Date().addingTimeInterval(900))
        tokenManager.stubbedGeneratedToken = resetToken

        let result = recoverPasswordSync(sut: sut, email: "test@example.com")

        switch result {
        case let .success(response):
            XCTAssertEqual(response.message, "Password reset link sent to your email", "Expected success message to match")
            XCTAssertEqual(response.resetToken, "reset-token-123", "Expected reset token to match generated token")
        default:
            XCTFail("Expected success, got \(String(describing: result))")
        }
    }

    func test_recoverPassword_generatesResetToken_onValidEmail() {
        let (sut, _, _, tokenManager, _) = makeSUT()

        _ = recoverPasswordSync(sut: sut, email: "test@example.com")

        XCTAssertEqual(tokenManager.generateResetTokenCallCount, 1, "Expected generateResetToken to be called once")
        XCTAssertEqual(tokenManager.generateResetTokenArgs, ["test@example.com"], "Expected generateResetToken to be called with correct email")
    }

    func test_recoverPassword_deliversTokenGenerationError_whenTokenGenerationFails() {
        let (sut, _, _, tokenManager, _) = makeSUT()
        tokenManager.shouldThrowOnGenerate = true

        let result = recoverPasswordSync(sut: sut, email: "test@example.com")

        switch result {
        case let .failure(error):
            XCTAssertEqual(error, PasswordRecoveryError.tokenGenerationFailed, "Expected token generation failed error")
        default:
            XCTFail("Expected token generation error, got \(String(describing: result))")
        }
    }

    func test_recoverPassword_deliversInvalidEmailError_onInvalidEmail() {
        let (sut, _, _, _, _) = makeSUT()

        let result = recoverPasswordSync(sut: sut, email: "invalid")

        switch result {
        case let .failure(error):
            XCTAssertEqual(error, PasswordRecoveryError.invalidEmailFormat, "Expected invalid email format error")
        default:
            XCTFail("Expected invalid email error, got \(String(describing: result))")
        }
    }

    func test_recoverPassword_deliversRateLimitError_whenRateLimitExceeded() {
        let (sut, rateLimiterSpy, _, _, _) = makeSUT()
        rateLimiterSpy.stubbedValidationResult = .failure(.rateLimitExceeded(retryAfterSeconds: 300))

        let result = recoverPasswordSync(sut: sut, email: "test@example.com")

        switch result {
        case let .failure(error):
            if case let .rateLimitExceeded(retryAfterSeconds) = error {
                XCTAssertEqual(retryAfterSeconds, 300, "Expected retry after seconds to match")
            } else {
                XCTFail("Expected rateLimitExceeded error, got \(error)")
            }
        default:
            XCTFail("Expected rate limit error, got \(String(describing: result))")
        }
    }

    func test_recoverPassword_recordsAttempt_onValidEmail() {
        let (sut, rateLimiterSpy, _, _, _) = makeSUT()

        _ = recoverPasswordSync(sut: sut, email: "test@example.com")

        XCTAssertEqual(rateLimiterSpy.recordedAttempts.count, 1, "Expected one recorded attempt")
        XCTAssertEqual(rateLimiterSpy.recordedAttempts.first?.email, "test@example.com", "Expected recorded email to match")
    }

    func test_recoverPassword_doesNotRecordAttempt_onInvalidEmail() {
        let (sut, rateLimiterSpy, _, _, _) = makeSUT()

        _ = recoverPasswordSync(sut: sut, email: "invalid")

        XCTAssertEqual(rateLimiterSpy.recordedAttempts.count, 0, "Expected no recorded attempts for invalid email")
    }

    func test_recoverPassword_doesNotGenerateToken_whenRateLimitExceeded() {
        let (sut, rateLimiterSpy, _, tokenManager, _) = makeSUT()
        rateLimiterSpy.stubbedValidationResult = .failure(.rateLimitExceeded(retryAfterSeconds: 300))

        _ = recoverPasswordSync(sut: sut, email: "test@example.com")

        XCTAssertEqual(tokenManager.generateResetTokenCallCount, 0, "Expected no token generation when rate limit exceeded")
    }

    func test_recoverPassword_deliversEmailNotFoundError_onUnknownEmail() {
        let (sut, _, apiSpy, _, _) = makeSUT()
        apiSpy.stubbedResult = .failure(.emailNotFound)

        let result = recoverPasswordSync(sut: sut, email: "unknown@example.com")

        switch result {
        case let .failure(error):
            XCTAssertEqual(error, PasswordRecoveryError.emailNotFound, "Expected email not found error")
        default:
            XCTFail("Expected email not found error, got \(String(describing: result))")
        }
    }

    func test_recoverPassword_deliversNetworkError_onNetworkFailure() {
        let (sut, _, apiSpy, _, _) = makeSUT()
        apiSpy.stubbedResult = .failure(.network)

        let result = recoverPasswordSync(sut: sut, email: "test@example.com")

        switch result {
        case let .failure(error):
            XCTAssertEqual(error, PasswordRecoveryError.network, "Expected network error")
        default:
            XCTFail("Expected network error, got \(String(describing: result))")
        }
    }

    func test_recoverPassword_logsAuditAttempt_onValidEmail() {
        let (sut, _, _, _, auditLogger) = makeSUT()

        _ = recoverPasswordSync(sut: sut, email: "test@example.com")

        XCTAssertEqual(auditLogger.logRecoveryAttemptCallCount, 1, "Expected audit log to be called once")
        XCTAssertEqual(auditLogger.loggedAuditLogs.first?.email, "test@example.com", "Expected audit log email to match")
        XCTAssertEqual(auditLogger.loggedAuditLogs.first?.outcome, .success, "Expected success outcome in audit log")
    }

    func test_recoverPassword_logsAuditAttempt_onInvalidEmail() {
        let (sut, _, _, _, auditLogger) = makeSUT()

        _ = recoverPasswordSync(sut: sut, email: "invalid")

        XCTAssertEqual(auditLogger.logRecoveryAttemptCallCount, 1, "Expected audit log to be called once")
        XCTAssertEqual(auditLogger.loggedAuditLogs.first?.email, "invalid", "Expected audit log email to match")
        XCTAssertEqual(auditLogger.loggedAuditLogs.first?.outcome, .invalidEmailFormat, "Expected invalid email outcome in audit log")
    }

    // MARK: - Helpers

    private func recoverPasswordSync(sut: UserPasswordRecoveryUseCase, email: String) -> Result<PasswordRecoveryResponse, PasswordRecoveryError>? {
        let exp = expectation(description: "Wait for recovery")
        var receivedResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>?
        sut.recoverPassword(email: email, ipAddress: "192.168.1.1", userAgent: "TestAgent/1.0") { result in
            receivedResult = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        return receivedResult
    }

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: UserPasswordRecoveryUseCase, rateLimiterSpy: PasswordRecoveryRateLimiterSpy, apiSpy: PasswordRecoveryAPISpy, tokenManager: PasswordResetTokenManagerSpy, auditLogger: PasswordRecoveryAuditLoggerSpy) {
        let rateLimiterSpy = PasswordRecoveryRateLimiterSpy()
        let apiSpy = PasswordRecoveryAPISpy()
        let tokenManager = PasswordResetTokenManagerSpy()
        let auditLogger = PasswordRecoveryAuditLoggerSpy()
        let sut = RemoteUserPasswordRecoveryUseCase(api: apiSpy, rateLimiter: rateLimiterSpy, tokenManager: tokenManager, auditLogger: auditLogger)

        trackForMemoryLeaks(sut, file: file, line: line)

        return (sut, rateLimiterSpy, apiSpy, tokenManager, auditLogger)
    }
}
