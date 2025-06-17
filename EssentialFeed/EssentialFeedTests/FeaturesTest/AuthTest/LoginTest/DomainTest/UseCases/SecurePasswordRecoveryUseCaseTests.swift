import EssentialFeed
import XCTest

final class SecurePasswordRecoveryUseCaseTests: XCTestCase {
    func test_recoverPassword_withValidCaptcha_proceedsToBaseUseCase() {
        let (sut, baseUseCase, captchaValidator, _, _) = makeSUT()
        captchaValidator.stubbedResult = CaptchaValidationResult(isValid: true, score: 0.8, challengeId: "test")

        let exp = expectation(description: "Wait for completion")
        var receivedResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>?

        sut.recoverPasswordWithCaptcha(
            email: "test@example.com",
            ipAddress: "192.168.1.1",
            userAgent: "Mozilla/5.0",
            captchaResponse: "valid-captcha-response"
        ) { result in
            receivedResult = result
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(baseUseCase.recoverPasswordCallCount, 1, "Should call base use case with valid CAPTCHA")
        XCTAssertNotNil(receivedResult, "Should receive result")
    }

    func test_recoverPassword_withInvalidCaptcha_returnsError() {
        let (sut, baseUseCase, captchaValidator, _, securityLogger) = makeSUT()
        captchaValidator.stubbedResult = CaptchaValidationResult(isValid: false, score: nil, challengeId: nil)

        let exp = expectation(description: "Wait for completion")
        var receivedError: PasswordRecoveryError?

        sut.recoverPasswordWithCaptcha(
            email: "test@example.com",
            ipAddress: "192.168.1.1",
            userAgent: "Mozilla/5.0",
            captchaResponse: "invalid-captcha-response"
        ) { result in
            if case let .failure(error) = result {
                receivedError = error
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(baseUseCase.recoverPasswordCallCount, 0, "Should not call base use case with invalid CAPTCHA")
        XCTAssertEqual(receivedError, .captchaFailed, "Should return CAPTCHA failed error")
        XCTAssertEqual(securityLogger.loggedEvents.count, 1, "Should log security event")
        XCTAssertEqual(securityLogger.loggedEvents.first?.event, .captchaFailed, "Should log CAPTCHA failed event")
    }

    func test_recoverPassword_withLowCaptchaScore_returnsError() {
        let (sut, baseUseCase, captchaValidator, _, securityLogger) = makeSUT()
        captchaValidator.stubbedResult = CaptchaValidationResult(isValid: true, score: 0.2, challengeId: "test")

        let exp = expectation(description: "Wait for completion")
        var receivedError: PasswordRecoveryError?

        sut.recoverPasswordWithCaptcha(
            email: "test@example.com",
            ipAddress: "192.168.1.1",
            userAgent: "Mozilla/5.0",
            captchaResponse: "low-score-response"
        ) { result in
            if case let .failure(error) = result {
                receivedError = error
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(baseUseCase.recoverPasswordCallCount, 0, "Should not call base use case with low CAPTCHA score")
        XCTAssertEqual(receivedError, .captchaFailed, "Should return CAPTCHA failed error")
        XCTAssertEqual(securityLogger.loggedEvents.count, 1, "Should log security event")
        XCTAssertEqual(securityLogger.loggedEvents.first?.event, .lowCaptchaScore(score: 0.2), "Should log low score event")
    }

    func test_recoverPassword_withBotDetected_returnsError() {
        let (sut, baseUseCase, _, botDetection, _) = makeSUT()
        botDetection.stubbedResult = .bot(confidence: 0.9)

        let exp = expectation(description: "Wait for completion")
        var receivedError: PasswordRecoveryError?

        sut.recoverPassword(
            email: "test@example.com",
            ipAddress: "192.168.1.1",
            userAgent: "bot-user-agent"
        ) { result in
            if case let .failure(error) = result {
                receivedError = error
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(baseUseCase.recoverPasswordCallCount, 0, "Should not call base use case when bot detected")
        XCTAssertEqual(receivedError, .botDetected, "Should return bot detected error")
    }

    func test_recoverPassword_withSuspiciousActivity_requiresCaptcha() {
        let (sut, baseUseCase, _, botDetection, _) = makeSUT()
        botDetection.stubbedResult = .suspicious(reason: "high_frequency_requests")

        let exp = expectation(description: "Wait for completion")
        var receivedError: PasswordRecoveryError?

        sut.recoverPassword(
            email: "test@example.com",
            ipAddress: "192.168.1.1",
            userAgent: "Mozilla/5.0"
        ) { result in
            if case let .failure(error) = result {
                receivedError = error
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(baseUseCase.recoverPasswordCallCount, 0, "Should not call base use case without CAPTCHA for suspicious activity")
        XCTAssertEqual(receivedError, .captchaRequired, "Should require CAPTCHA for suspicious activity")
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (
        sut: SecurePasswordRecoveryUseCase,
        baseUseCase: UserPasswordRecoveryUseCaseSpy,
        captchaValidator: CaptchaValidatorSpy,
        botDetection: BotDetectionServiceSpy,
        securityLogger: SecurityEventLoggerSpy
    ) {
        let baseUseCase = UserPasswordRecoveryUseCaseSpy()
        let captchaValidator = CaptchaValidatorSpy()
        let botDetection = BotDetectionServiceSpy()
        let securityLogger = SecurityEventLoggerSpy()

        let sut = SecurePasswordRecoveryUseCase(
            baseUseCase: baseUseCase,
            captchaValidator: captchaValidator,
            botDetection: botDetection,
            securityLogger: securityLogger
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(baseUseCase, file: file, line: line)
        trackForMemoryLeaks(captchaValidator, file: file, line: line)
        trackForMemoryLeaks(botDetection, file: file, line: line)
        trackForMemoryLeaks(securityLogger, file: file, line: line)

        return (sut, baseUseCase, captchaValidator, botDetection, securityLogger)
    }
}
