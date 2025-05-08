import EssentialFeed
import XCTest

final class UserPasswordRecoveryIntegrationTests: XCTestCase {
    func test_recovery_succeeds_withValidEmail_andNotifiesSuccess() async {
        // Arrange
        let (sut, api) = makeSUT()
        let validEmail = "user@example.com"
        api.result = .success(PasswordRecoveryResponse(message: "OK"))
        var receivedResponse: PasswordRecoveryResponse?

        sut.recoverPassword(email: validEmail) { result in
            if case let .success(response) = result {
                receivedResponse = response
            }
        }

        // Assert
        XCTAssertEqual(api.requestedEmails, [validEmail])
        XCTAssertEqual(receivedResponse?.message, "OK")
    }

    func test_recovery_fails_withInvalidEmailFormat_andDoesNotSendRequest() async {
        // Arrange
        let (sut, api) = makeSUT()
        let invalidEmail = "invalid-email-format"
        var receivedError: PasswordRecoveryError?

        sut.recoverPassword(email: invalidEmail) { result in
            if case let .failure(error) = result {
                receivedError = error
            }
        }

        // Assert
        XCTAssertEqual(api.requestedEmails, [])
        XCTAssertEqual(receivedError, .invalidEmailFormat)
    }

    func test_recovery_fails_withUnregisteredEmail_andNotifiesFailure() async {
        // Arrange
        let (sut, api) = makeSUT()
        let validEmail = "notfound@example.com"
        api.result = .failure(.emailNotFound)
        var receivedError: PasswordRecoveryError?

        sut.recoverPassword(email: validEmail) { result in
            if case let .failure(error) = result {
                receivedError = error
            }
        }

        // Assert
        XCTAssertEqual(api.requestedEmails, [validEmail])
        XCTAssertEqual(receivedError, .emailNotFound)
    }

    func test_recovery_fails_onConnectivityError_andNotifiesFailure() async {
        // Arrange
        let (sut, api) = makeSUT()
        let validEmail = "user@example.com"
        api.result = .failure(.network)
        var receivedError: PasswordRecoveryError?

        sut.recoverPassword(email: validEmail) { result in
            if case let .failure(error) = result {
                receivedError = error
            }
        }

        // Assert
        XCTAssertEqual(api.requestedEmails, [validEmail])
        XCTAssertEqual(receivedError, .network)
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (UserPasswordRecoveryUseCase, PasswordRecoveryAPISpy) {
        let api = PasswordRecoveryAPISpy()
        let sut = RemoteUserPasswordRecoveryUseCase(api: api)
        trackForMemoryLeaks(api, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, api)
    }

    // MARK: - Test Doubles

    private class PasswordRecoveryAPISpy: PasswordRecoveryAPI {
        var requestedEmails: [String] = []
        var result: Result<PasswordRecoveryResponse, PasswordRecoveryError> = .failure(.network)

        func recover(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
            requestedEmails.append(email)
            completion(result)
        }
    }
}
