import EssentialFeed
import Foundation
import XCTest

final class UserLoginUseCaseTests: XCTestCase {
    private let validEmail = "user@example.com"
    private let validPassword = "password123"
    private let invalidPassword = "wrongpass"
    private let validToken = "token123"

    func test_login_delegatesToLoginService() async {
        let (sut, loginServiceSpy) = makeSUT()
        let credentials = LoginCredentials(email: validEmail, password: validPassword)
        loginServiceSpy.stubbedResult = .success(LoginResponse(token: validToken))

        _ = await sut.login(with: credentials)

        XCTAssertEqual(loginServiceSpy.executeCallCount, 1, "Should delegate to login service")
        XCTAssertEqual(loginServiceSpy.lastCredentials, credentials, "Should pass correct credentials")
    }

    func test_login_withInvalidCredentials_returnsServiceError() async {
        let (sut, loginServiceSpy) = makeSUT()
        let credentials = LoginCredentials(email: validEmail, password: invalidPassword)
        loginServiceSpy.stubbedResult = .failure(LoginError.invalidCredentials)

        let result = await sut.login(with: credentials)

        switch result {
        case let .failure(error):
            XCTAssertEqual(error, LoginError.invalidCredentials, "Should return service error")
            XCTAssertEqual(loginServiceSpy.executeCallCount, 1, "Should call service")
            XCTAssertEqual(loginServiceSpy.lastCredentials, credentials, "Should pass credentials to service")
        default:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_successful_returnsServiceResult() async {
        let (sut, loginServiceSpy) = makeSUT()
        let credentials = LoginCredentials(email: validEmail, password: validPassword)
        let expectedResponse = LoginResponse(token: validToken)
        loginServiceSpy.stubbedResult = .success(expectedResponse)

        let result = await sut.login(with: credentials)

        switch result {
        case let .success(response):
            XCTAssertEqual(response.token, validToken, "Should return service response")
            XCTAssertEqual(loginServiceSpy.executeCallCount, 1, "Should call service")
            XCTAssertEqual(loginServiceSpy.lastCredentials, credentials, "Should pass credentials to service")
        default:
            XCTFail("Expected success, got failure")
        }
    }

    func test_login_whenServiceFailsWithTokenStorage_returnsError() async {
        let (sut, loginServiceSpy) = makeSUT()
        let credentials = LoginCredentials(email: validEmail, password: validPassword)
        loginServiceSpy.stubbedResult = .failure(LoginError.tokenStorageFailed)

        let result = await sut.login(with: credentials)

        switch result {
        case let .failure(error):
            XCTAssertEqual(error, LoginError.tokenStorageFailed, "Should return service error")
            XCTAssertEqual(loginServiceSpy.executeCallCount, 1, "Should call service")
        default:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_whenAccountIsLocked_returnsServiceError() async {
        let (sut, loginServiceSpy) = makeSUT()
        let credentials = LoginCredentials(email: validEmail, password: validPassword)
        loginServiceSpy.stubbedResult = .failure(.accountLocked(remainingTime: 123))

        let result = await sut.login(with: credentials)

        switch result {
        case let .failure(error):
            if case let LoginError.accountLocked(remainingTime) = error {
                XCTAssertEqual(remainingTime, 123, "Should return correct remaining time")
            } else {
                XCTFail("Expected accountLocked error, got \(error)")
            }
            XCTAssertEqual(loginServiceSpy.executeCallCount, 1, "Should call service")
        default:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_withNetworkError_returnsServiceError() async {
        let (sut, loginServiceSpy) = makeSUT()
        let credentials = LoginCredentials(email: validEmail, password: validPassword)
        loginServiceSpy.stubbedResult = .failure(.network)

        let result = await sut.login(with: credentials)

        switch result {
        case let .failure(error):
            XCTAssertEqual(error, LoginError.network, "Should return network error from service")
            XCTAssertEqual(loginServiceSpy.executeCallCount, 1, "Should call service")
        default:
            XCTFail("Expected failure, got success")
        }
    }

    func test_login_passesCredentialsExactly() async {
        let (sut, loginServiceSpy) = makeSUT()
        let expectedCredentials = LoginCredentials(email: "test@test.com", password: "testpass")
        loginServiceSpy.stubbedResult = .success(LoginResponse(token: "any"))

        _ = await sut.login(with: expectedCredentials)

        XCTAssertEqual(loginServiceSpy.lastCredentials, expectedCredentials, "Should pass exact credentials to service")
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (UserLoginUseCase, LoginServiceSpy) {
        let loginServiceSpy = LoginServiceSpy()
        let sut = UserLoginUseCase(loginService: loginServiceSpy)
        trackForMemoryLeaks(loginServiceSpy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, loginServiceSpy)
    }
}

// MARK: - LoginServiceSpy

private class LoginServiceSpy: LoginService {
    private(set) var executeCallCount = 0
    private(set) var lastCredentials: LoginCredentials?
    var stubbedResult: Result<LoginResponse, LoginError> = .failure(.invalidCredentials)

    func execute(credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
        executeCallCount += 1
        lastCredentials = credentials
        return stubbedResult
    }
}
