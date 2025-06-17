import EssentialFeed
import XCTest

final class UserPasswordRecoveryUseCaseDomainTests: XCTestCase {
    func test_recoverPassword_deliversSuccess_onValidEmailWithinRateLimit() {
        let (sut, _, _) = makeSUT(apiResult: .success(PasswordRecoveryResponse(message: "OK")))

        let result = recoverPasswordSync(sut: sut, email: "test@example.com")

        switch result {
        case let .success(response):
            XCTAssertEqual(response.message, "OK")
        default:
            XCTFail("Expected success, got \(String(describing: result))")
        }
    }

    func test_recoverPassword_deliversInvalidEmailError_onInvalidEmail() {
        let (sut, _, _) = makeSUT(apiResult: .failure(PasswordRecoveryError.invalidEmailFormat))

        let result = recoverPasswordSync(sut: sut, email: "invalid")

        switch result {
        case let .failure(error):
            XCTAssertEqual(error, PasswordRecoveryError.invalidEmailFormat)
        default:
            XCTFail("Expected invalid email error, got \(String(describing: result))")
        }
    }

    func test_recoverPassword_deliversRateLimitError_whenRateLimitExceeded() {
        let (sut, rateLimiterSpy, _) = makeSUT()
        rateLimiterSpy.stubbedValidationResult = .failure(.rateLimitExceeded(retryAfterSeconds: 300))

        let result = recoverPasswordSync(sut: sut, email: "test@example.com")

        switch result {
        case let .failure(error):
            if case let .rateLimitExceeded(retryAfterSeconds) = error {
                XCTAssertEqual(retryAfterSeconds, 300)
            } else {
                XCTFail("Expected rateLimitExceeded error, got \(error)")
            }
        default:
            XCTFail("Expected rate limit error, got \(String(describing: result))")
        }
    }

    func test_recoverPassword_recordsAttempt_onValidEmail() {
        let (sut, rateLimiterSpy, _) = makeSUT()

        _ = recoverPasswordSync(sut: sut, email: "test@example.com")

        XCTAssertEqual(rateLimiterSpy.recordedAttempts.count, 1)
        XCTAssertEqual(rateLimiterSpy.recordedAttempts.first?.email, "test@example.com")
    }

    func test_recoverPassword_doesNotRecordAttempt_onInvalidEmail() {
        let (sut, rateLimiterSpy, _) = makeSUT()

        _ = recoverPasswordSync(sut: sut, email: "invalid")

        XCTAssertEqual(rateLimiterSpy.recordedAttempts.count, 0)
    }

    func test_recoverPassword_doesNotCallAPI_whenRateLimitExceeded() {
        let (sut, rateLimiterSpy, apiSpy) = makeSUT()
        rateLimiterSpy.stubbedValidationResult = .failure(.rateLimitExceeded(retryAfterSeconds: 300))

        _ = recoverPasswordSync(sut: sut, email: "test@example.com")

        XCTAssertEqual(apiSpy.recoverCallCount, 0)
    }

    func test_recoverPassword_deliversEmailNotFoundError_onUnknownEmail() {
        let (sut, _, _) = makeSUT(apiResult: .failure(PasswordRecoveryError.emailNotFound))

        let result = recoverPasswordSync(sut: sut, email: "unknown@example.com")

        switch result {
        case let .failure(error):
            XCTAssertEqual(error, PasswordRecoveryError.emailNotFound)
        default:
            XCTFail("Expected email not found error, got \(String(describing: result))")
        }
    }

    func test_recoverPassword_deliversNetworkError_onNetworkFailure() {
        let (sut, _, _) = makeSUT(apiResult: .failure(PasswordRecoveryError.network))

        let result = recoverPasswordSync(sut: sut, email: "test@example.com")

        switch result {
        case let .failure(error):
            XCTAssertEqual(error, PasswordRecoveryError.network)
        default:
            XCTFail("Expected network error, got \(String(describing: result))")
        }
    }

    // MARK: - Helpers

    private func recoverPasswordSync(sut: UserPasswordRecoveryUseCase, email: String) -> Result<PasswordRecoveryResponse, PasswordRecoveryError>? {
        let exp = expectation(description: "Wait for recovery")
        var receivedResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>?
        sut.recoverPassword(email: email) { result in
            receivedResult = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        return receivedResult
    }

    private func makeSUT(
        apiResult: Result<PasswordRecoveryResponse, PasswordRecoveryError> = .success(PasswordRecoveryResponse(message: "OK")),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: UserPasswordRecoveryUseCase, rateLimiterSpy: PasswordRecoveryRateLimiterSpy, apiSpy: PasswordRecoveryAPISpy) {
        let rateLimiterSpy = PasswordRecoveryRateLimiterSpy()
        let apiSpy = PasswordRecoveryAPISpy(result: apiResult)
        let sut = RemoteUserPasswordRecoveryUseCase(api: apiSpy, rateLimiter: rateLimiterSpy)
        trackForMemoryLeaks(rateLimiterSpy, file: file, line: line)
        trackForMemoryLeaks(apiSpy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, rateLimiterSpy, apiSpy)
    }
}

// MARK: - Test Doubles

private final class PasswordRecoveryRateLimiterSpy: PasswordRecoveryRateLimiter {
    var stubbedValidationResult: Result<Void, PasswordRecoveryError> = .success(())
    var recordedAttempts: [(email: String, ipAddress: String?)] = []

    func isAllowed(for _: String) -> Result<Void, PasswordRecoveryError> {
        stubbedValidationResult
    }

    func recordAttempt(for email: String, ipAddress: String?) {
        recordedAttempts.append((email: email, ipAddress: ipAddress))
    }
}

private final class PasswordRecoveryAPISpy: PasswordRecoveryAPI {
    private let result: Result<PasswordRecoveryResponse, PasswordRecoveryError>
    var recoverCallCount = 0

    init(result: Result<PasswordRecoveryResponse, PasswordRecoveryError>) {
        self.result = result
    }

    func recover(email _: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        recoverCallCount += 1
        completion(result)
    }
}
