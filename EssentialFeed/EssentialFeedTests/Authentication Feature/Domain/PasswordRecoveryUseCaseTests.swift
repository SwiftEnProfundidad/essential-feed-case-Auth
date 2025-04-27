import XCTest
import EssentialFeed

final class PasswordRecoveryUseCaseTests: XCTestCase {
    func test_recoverPassword_deliversSuccess_onValidEmail() {
        // Arrange: Setup a stub API and SUT
        let api = PasswordRecoveryAPIStub(result: .success(PasswordRecoveryResponse(message: "OK")))
        let sut = PasswordRecovery(api: api)
        let exp = expectation(description: "Wait for recovery")
        var receivedResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>?
        
        // Act
        sut.recoverPassword(email: "test@example.com") { result in
            receivedResult = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        
        // Assert
        switch receivedResult {
        case let .success(response):
            XCTAssertEqual(response.message, "OK")
        default:
            XCTFail("Expected success, got \(String(describing: receivedResult))")
        }
    }

    func test_recoverPassword_deliversInvalidEmailError_onInvalidEmail() {
        let api = PasswordRecoveryAPIStub(result: .failure(.invalidEmailFormat))
        let sut = PasswordRecovery(api: api)
        let exp = expectation(description: "Wait for recovery")
        var receivedResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>?
        
        sut.recoverPassword(email: "invalid") { result in
            receivedResult = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        
        switch receivedResult {
        case let .failure(error):
            XCTAssertEqual(error, .invalidEmailFormat)
        default:
            XCTFail("Expected invalid email error, got \(String(describing: receivedResult))")
        }
    }

    func test_recoverPassword_deliversEmailNotFoundError_onUnknownEmail() {
        let api = PasswordRecoveryAPIStub(result: .failure(.emailNotFound))
        let sut = PasswordRecovery(api: api)
        let exp = expectation(description: "Wait for recovery")
        var receivedResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>?
        
        sut.recoverPassword(email: "unknown@example.com") { result in
            receivedResult = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        
        switch receivedResult {
        case let .failure(error):
            XCTAssertEqual(error, .emailNotFound)
        default:
            XCTFail("Expected email not found error, got \(String(describing: receivedResult))")
        }
    }

    func test_recoverPassword_deliversNetworkError_onNetworkFailure() {
        let api = PasswordRecoveryAPIStub(result: .failure(.network))
        let sut = PasswordRecovery(api: api)
        let exp = expectation(description: "Wait for recovery")
        var receivedResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>?
        
        sut.recoverPassword(email: "test@example.com") { result in
            receivedResult = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        
        switch receivedResult {
        case let .failure(error):
            XCTAssertEqual(error, .network)
        default:
            XCTFail("Expected network error, got \(String(describing: receivedResult))")
        }
    }
}

// Stub API for testing
private class PasswordRecoveryAPIStub: PasswordRecoveryAPI {
    private let result: Result<PasswordRecoveryResponse, PasswordRecoveryError>
    init(result: Result<PasswordRecoveryResponse, PasswordRecoveryError>) {
        self.result = result
    }
    func recoverPassword(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        completion(result)
    }
}
