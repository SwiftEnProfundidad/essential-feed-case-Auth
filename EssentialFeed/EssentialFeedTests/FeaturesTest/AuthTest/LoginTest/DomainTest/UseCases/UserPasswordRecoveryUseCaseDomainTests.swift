import EssentialFeed
import XCTest

final class UserPasswordRecoveryUseCaseDomainTests: XCTestCase {
    func test_recoverPassword_deliversSuccess_onValidEmail() {
        let (sut, _) = makeSUT(apiResult: .success(PasswordRecoveryResponse(message: "OK")))
        let exp = expectation(description: "Wait for recovery")
        var receivedResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>?

        sut.recoverPassword(email: "test@example.com") { result in
            receivedResult = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        switch receivedResult {
        case let .success(response):
            XCTAssertEqual(response.message, "OK")
        default:
            XCTFail("Expected success, got \(String(describing: receivedResult))")
        }
    }

    func test_recoverPassword_deliversInvalidEmailError_onInvalidEmail() {
        let (sut, _) = makeSUT(apiResult: .failure(PasswordRecoveryError.invalidEmailFormat))
        let receivedResult = recoverPasswordSync(sut: sut, email: "invalid")

        switch receivedResult {
        case let .failure(error):
            XCTAssertEqual(error, PasswordRecoveryError.invalidEmailFormat)
        default:
            XCTFail("Expected invalid email error, got \(String(describing: receivedResult))")
        }
    }

    func test_recoverPassword_deliversEmailNotFoundError_onUnknownEmail() {
        let (sut, _) = makeSUT(apiResult: .failure(PasswordRecoveryError.emailNotFound))
        let receivedResult = recoverPasswordSync(sut: sut, email: "unknown@example.com")

        switch receivedResult {
        case let .failure(error):
            XCTAssertEqual(error, PasswordRecoveryError.emailNotFound)
        default:
            XCTFail("Expected email not found error, got \(String(describing: receivedResult))")
        }
    }

    func test_recoverPassword_deliversNetworkError_onNetworkFailure() {
        let (sut, _) = makeSUT(apiResult: .failure(PasswordRecoveryError.network))
        let exp = expectation(description: "Wait for recovery")
        var receivedResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>?

        sut.recoverPassword(email: "test@example.com") { result in
            receivedResult = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        switch receivedResult {
        case let .failure(error):
            XCTAssertEqual(error, PasswordRecoveryError.network)
        default:
            XCTFail("Expected network error, got \(String(describing: receivedResult))")
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
        apiResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>,
        file: StaticString = #file, line: UInt = #line
    ) -> (sut: UserPasswordRecoveryUseCase, api: PasswordRecoveryAPIStub) {
        let api = PasswordRecoveryAPIStub(result: apiResult)
        let sut = RemoteUserPasswordRecoveryUseCase(api: api)
        trackForMemoryLeaks(api, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, api)
    }
}

// Stub API for testing
private class PasswordRecoveryAPIStub: PasswordRecoveryAPI {
    private let result: Result<PasswordRecoveryResponse, PasswordRecoveryError>
    init(result: Result<PasswordRecoveryResponse, PasswordRecoveryError>) {
        self.result = result
    }

    func recover(email _: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        completion(result)
    }
}
