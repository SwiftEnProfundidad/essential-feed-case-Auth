import EssentialFeed
import XCTest

final class SecurePasswordRecoveryUseCaseTests: XCTestCase {
    func test_recoverPassword_withValidCaptcha_proceedsToBaseUseCase() {
        let (sut, baseUseCase, securityValidationService, _) = makeSUT()
        securityValidationService.stubbedResult = SecurityValidationResult.allowed

        let exp = expectation(description: "Wait for completion")
        var receivedResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>?

        sut.recoverPassword(
            email: "test@example.com",
            ipAddress: "192.168.1.1",
            userAgent: "Mozilla/5.0"
        ) { result in
            receivedResult = result
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(baseUseCase.recoverPasswordCallCount, 1, "Should call base use case when security validation allows")
        XCTAssertNotNil(receivedResult, "Should receive result")
    }

    func test_recoverPassword_withDeniedSecurity_returnsError() {
        let (sut, baseUseCase, securityValidationService, securityLogger) = makeSUT()
        securityValidationService.stubbedResult = SecurityValidationResult.denied(SecurityEvent.captchaFailed)

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

        XCTAssertEqual(baseUseCase.recoverPasswordCallCount, 0, "Should not call base use case when security denied")
        XCTAssertNotNil(receivedError, "Should return error")
        XCTAssertEqual(securityLogger.loggedEvents.count, 1, "Should log security event")
        XCTAssertEqual(securityLogger.loggedEvents.first?.event, SecurityEvent.captchaFailed, "Should log correct event")
    }

    func test_recoverPassword_withRequiresCaptcha_returnsRateLimitError() {
        let (sut, baseUseCase, securityValidationService, securityLogger) = makeSUT()
        securityValidationService.stubbedResult = SecurityValidationResult.requiresCaptcha(SecurityEvent.suspiciousActivity(reason: "high_frequency"))

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

        XCTAssertEqual(baseUseCase.recoverPasswordCallCount, 0, "Should not call base use case when CAPTCHA required")
        if case let .rateLimitExceeded(retryAfterSeconds) = receivedError {
            XCTAssertEqual(retryAfterSeconds, 0, "Should require immediate retry with CAPTCHA")
        } else {
            XCTFail("Expected rateLimitExceeded error")
        }
        XCTAssertEqual(securityLogger.loggedEvents.count, 1, "Should log security event")
    }

    func test_recoverPassword_withSecurityValidationError_returnsUnknownError() {
        let (sut, baseUseCase, securityValidationService, securityLogger) = makeSUT()
        securityValidationService.shouldThrowError = true

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

        XCTAssertEqual(baseUseCase.recoverPasswordCallCount, 0, "Should not call base use case when validation throws")
        XCTAssertEqual(receivedError, .unknown, "Should return unknown error")
        XCTAssertEqual(securityLogger.loggedEvents.count, 1, "Should log error event")
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (
        sut: SecurePasswordRecoveryUseCase,
        baseUseCase: TestUserPasswordRecoveryUseCase,
        securityValidationService: TestSecurityValidationService,
        securityLogger: TestSecurityEventLogger
    ) {
        let baseUseCase = TestUserPasswordRecoveryUseCase()
        let securityValidationService = TestSecurityValidationService()
        let securityLogger = TestSecurityEventLogger()

        let sut = SecurePasswordRecoveryUseCase(
            baseUseCase: baseUseCase,
            securityValidationService: securityValidationService,
            securityLogger: securityLogger
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(baseUseCase, file: file, line: line)
        trackForMemoryLeaks(securityValidationService, file: file, line: line)
        trackForMemoryLeaks(securityLogger, file: file, line: line)

        return (sut, baseUseCase, securityValidationService, securityLogger)
    }
}

private final class TestUserPasswordRecoveryUseCase: UserPasswordRecoveryUseCase {
    private(set) var recoverPasswordCallCount = 0
    private(set) var receivedEmails = [String]()
    private(set) var receivedIPAddresses = [String?]()
    private(set) var receivedUserAgents = [String?]()

    func recoverPassword(email: String, ipAddress: String? = nil, userAgent: String? = nil, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        recoverPasswordCallCount += 1
        receivedEmails.append(email)
        receivedIPAddresses.append(ipAddress)
        receivedUserAgents.append(userAgent)
        completion(.success(PasswordRecoveryResponse(message: "Recovery successful")))
    }
}

private final class TestSecurityValidationService: SecurityValidationService {
    var stubbedResult: SecurityValidationResult = .allowed
    var shouldThrowError = false
    private(set) var validateCallCount = 0

    func validateSecurityRequirements(email _: String, ipAddress _: String?, userAgent _: String?, captchaResponse _: String?, requestPattern _: RequestPattern) async throws -> SecurityValidationResult {
        validateCallCount += 1

        if shouldThrowError {
            throw CaptchaError.networkError
        }

        return stubbedResult
    }
}

private final class TestSecurityEventLogger: SecurityEventLogger {
    private(set) var loggedEvents: [(event: SecurityEvent, email: String, ipAddress: String?, userAgent: String?)] = []

    func logSecurityEvent(_ event: SecurityEvent, email: String, ipAddress: String?, userAgent: String?) async {
        loggedEvents.append((event, email, ipAddress, userAgent))
    }
}
