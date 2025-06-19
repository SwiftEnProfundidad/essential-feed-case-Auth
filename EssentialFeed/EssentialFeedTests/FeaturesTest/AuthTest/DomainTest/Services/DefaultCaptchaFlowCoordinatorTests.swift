import EssentialFeed
import XCTest

final class DefaultCaptchaFlowCoordinatorTests: XCTestCase {
    func test_init_doesNotTriggerSideEffects() {
        let _ = makeSUT()
    }

    func test_shouldTriggerCaptcha_belowThreshold_returnsFalse() {
        let configuration = LoginSecurityConfiguration(maxAttempts: 5, blockDuration: 300, captchaThreshold: 3)
        let (sut, _) = makeSUT(configuration: configuration)

        let shouldTrigger = sut.shouldTriggerCaptcha(failedAttempts: 2)

        XCTAssertFalse(shouldTrigger, "Expected not to trigger CAPTCHA below threshold")
    }

    func test_shouldTriggerCaptcha_atThreshold_returnsTrue() {
        let configuration = LoginSecurityConfiguration(maxAttempts: 5, blockDuration: 300, captchaThreshold: 3)
        let (sut, _) = makeSUT(configuration: configuration)

        let shouldTrigger = sut.shouldTriggerCaptcha(failedAttempts: 3)

        XCTAssertTrue(shouldTrigger, "Expected to trigger CAPTCHA at threshold")
    }

    func test_shouldTriggerCaptcha_aboveThreshold_returnsTrue() {
        let configuration = LoginSecurityConfiguration(maxAttempts: 5, blockDuration: 300, captchaThreshold: 3)
        let (sut, _) = makeSUT(configuration: configuration)

        let shouldTrigger = sut.shouldTriggerCaptcha(failedAttempts: 4)

        XCTAssertTrue(shouldTrigger, "Expected to trigger CAPTCHA above threshold")
    }

    func test_handleCaptchaValidation_validToken_returnsSuccess() async {
        let (sut, validatorSpy) = makeSUT()
        validatorSpy.validateResult = CaptchaValidationResult(isValid: true)

        let result = await sut.handleCaptchaValidation(token: "valid-token", username: "test@example.com")

        XCTAssertEqual(validatorSpy.validateCallCount, 1, "Expected validator to be called once")
        XCTAssertEqual(validatorSpy.validateTokens, ["valid-token"], "Expected validator to be called with correct token")

        switch result {
        case .success:
            break
        case .failure:
            XCTFail("Expected success result")
        }
    }

    func test_handleCaptchaValidation_invalidToken_returnsFailure() async {
        let (sut, validatorSpy) = makeSUT()
        validatorSpy.validateResult = CaptchaValidationResult(isValid: false)

        let result = await sut.handleCaptchaValidation(token: "invalid-token", username: "test@example.com")

        XCTAssertEqual(validatorSpy.validateCallCount, 1, "Expected validator to be called once")
        XCTAssertEqual(validatorSpy.validateTokens, ["invalid-token"], "Expected validator to be called with correct token")

        switch result {
        case .success:
            XCTFail("Expected failure result")
        case let .failure(error):
            XCTAssertEqual(error, CaptchaError.invalidResponse, "Expected invalidResponse error")
        }
    }

    func test_handleCaptchaValidation_validatorThrowsError_returnsNetworkError() async {
        let (sut, validatorSpy) = makeSUT()
        validatorSpy.shouldThrowError = true

        let result = await sut.handleCaptchaValidation(token: "any-token", username: "test@example.com")

        switch result {
        case .success:
            XCTFail("Expected failure result")
        case let .failure(error):
            XCTAssertEqual(error, CaptchaError.networkError, "Expected networkError")
        }
    }

    // MARK: - Helpers

    private func makeSUT(
        configuration: LoginSecurityConfiguration = .default,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: DefaultCaptchaFlowCoordinator, validatorSpy: CaptchaValidatorTestSpy) {
        let validatorSpy = CaptchaValidatorTestSpy()
        let failedAttemptsStore = InMemoryFailedLoginAttemptsStore()
        let sut = DefaultCaptchaFlowCoordinator(
            captchaValidator: validatorSpy,
            failedAttemptsStore: failedAttemptsStore,
            configuration: configuration
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(validatorSpy, file: file, line: line)
        trackForMemoryLeaks(failedAttemptsStore, file: file, line: line)

        return (sut, validatorSpy)
    }
}

// MARK: - Test Doubles

private final class CaptchaValidatorTestSpy: CaptchaValidator {
    var validateCallCount = 0
    var validateTokens: [String] = []
    var validateResult = CaptchaValidationResult(isValid: true)
    var shouldThrowError = false

    func validateCaptcha(response: String, clientIP _: String?) async throws -> CaptchaValidationResult {
        validateCallCount += 1
        validateTokens.append(response)

        if shouldThrowError {
            throw CaptchaError.networkError
        }

        return validateResult
    }
}
