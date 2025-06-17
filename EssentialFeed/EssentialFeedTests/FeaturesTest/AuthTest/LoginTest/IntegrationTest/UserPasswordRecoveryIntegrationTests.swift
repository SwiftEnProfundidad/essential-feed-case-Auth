import EssentialFeed
import XCTest

final class UserPasswordRecoveryIntegrationTests: XCTestCase {
    func test_recovery_succeeds_withValidEmail_andNotifiesSuccess() async {
        let (sut, api) = makeSUT()
        let validEmail = "user@example.com"
        api.result = .success(PasswordRecoveryResponse(message: "OK"))
        var receivedResponse: PasswordRecoveryResponse?

        sut.recoverPassword(email: validEmail) { result in
            if case let .success(response) = result {
                receivedResponse = response
            }
        }

        XCTAssertEqual(api.requestedEmails, [validEmail])
        XCTAssertEqual(receivedResponse?.message, "OK")
    }

    func test_recovery_fails_withInvalidEmailFormat_andDoesNotSendRequest() async {
        let (sut, api) = makeSUT()
        let invalidEmail = "invalid-email-format"
        var receivedError: PasswordRecoveryError?

        sut.recoverPassword(email: invalidEmail) { result in
            if case let .failure(error) = result {
                receivedError = error
            }
        }

        XCTAssertEqual(api.requestedEmails, [])
        XCTAssertEqual(receivedError, .invalidEmailFormat)
    }

    func test_recovery_fails_withUnregisteredEmail_andNotifiesFailure() async {
        let (sut, api) = makeSUT()
        let validEmail = "notfound@example.com"
        api.result = .failure(.emailNotFound)
        var receivedError: PasswordRecoveryError?

        sut.recoverPassword(email: validEmail) { result in
            if case let .failure(error) = result {
                receivedError = error
            }
        }

        XCTAssertEqual(api.requestedEmails, [validEmail])
        XCTAssertEqual(receivedError, .emailNotFound)
    }

    func test_recovery_fails_onConnectivityError_andNotifiesFailure() async {
        let (sut, api) = makeSUT()
        let validEmail = "user@example.com"
        api.result = .failure(.network)
        var receivedError: PasswordRecoveryError?

        sut.recoverPassword(email: validEmail) { result in
            if case let .failure(error) = result {
                receivedError = error
            }
        }

        XCTAssertEqual(api.requestedEmails, [validEmail])
        XCTAssertEqual(receivedError, .network)
    }

    func test_recovery_fails_whenRateLimitExceeded_andDoesNotSendRequest() async {
        let (sut, api, rateLimiter) = makeSUTWithRateLimit()
        rateLimiter.stubbedValidationResult = .failure(.rateLimitExceeded(retryAfterSeconds: 300))
        let validEmail = "user@example.com"
        var receivedError: PasswordRecoveryError?

        sut.recoverPassword(email: validEmail) { result in
            if case let .failure(error) = result {
                receivedError = error
            }
        }

        XCTAssertEqual(api.requestedEmails, [])
        if case let .rateLimitExceeded(retryAfterSeconds) = receivedError {
            XCTAssertEqual(retryAfterSeconds, 300)
        } else {
            XCTFail("Expected rateLimitExceeded error, got \(String(describing: receivedError))")
        }
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (UserPasswordRecoveryUseCase, PasswordRecoveryAPISpy) {
        let api = PasswordRecoveryAPISpy()
        let rateLimiter = AlwaysAllowedRateLimiter()
        let sut = RemoteUserPasswordRecoveryUseCase(api: api, rateLimiter: rateLimiter)
        trackForMemoryLeaks(api, file: file, line: line)
        trackForMemoryLeaks(rateLimiter, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, api)
    }

    private func makeSUTWithRateLimit(file: StaticString = #filePath, line: UInt = #line) -> (UserPasswordRecoveryUseCase, PasswordRecoveryAPISpy, PasswordRecoveryRateLimiterSpy) {
        let api = PasswordRecoveryAPISpy()
        let rateLimiter = PasswordRecoveryRateLimiterSpy()
        let sut = RemoteUserPasswordRecoveryUseCase(api: api, rateLimiter: rateLimiter)
        trackForMemoryLeaks(api, file: file, line: line)
        trackForMemoryLeaks(rateLimiter, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, api, rateLimiter)
    }

    // MARK: - Test Doubles

    private final class PasswordRecoveryAPISpy: PasswordRecoveryAPI {
        var requestedEmails: [String] = []
        var result: Result<PasswordRecoveryResponse, PasswordRecoveryError> = .failure(.network)

        func recover(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
            requestedEmails.append(email)
            completion(result)
        }
    }

    private final class AlwaysAllowedRateLimiter: PasswordRecoveryRateLimiter {
        func isAllowed(for _: String) -> Result<Void, PasswordRecoveryError> {
            .success(())
        }

        func recordAttempt(for _: String, ipAddress _: String?) {
            // Do nothing for integration tests
        }
    }

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
}
