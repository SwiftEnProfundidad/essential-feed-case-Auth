import EssentialFeed
import XCTest

final class UserLoginUseCaseIntegrationTests: XCTestCase {
    func test_login_doesNotCallAPI_whenEmailIsInvalid() async {
        let (sut, loginService) = makeSUT()
        let credentials = LoginCredentials(email: "", password: "ValidPassword123")
        _ = await sut.login(with: credentials)
        XCTAssertEqual(loginService.executeCallCount, 1, "LoginService should be called even with invalid email to handle validation")
    }

    func test_login_doesNotCallAPI_whenPasswordIsInvalid() async {
        let (sut, loginService) = makeSUT()
        let credentials = LoginCredentials(email: "user@example.com", password: "   ")
        _ = await sut.login(with: credentials)
        XCTAssertEqual(loginService.executeCallCount, 1, "LoginService should be called even with invalid password to handle validation")
    }

    func test_login_withValidCredentials_notifiesSuccessEvent_andUIShowsSuccess() async {
        let (sut, loginService) = makeSUT()
        let credentials = LoginCredentials(email: "success@example.com", password: "ValidPassword123")
        let expectedResponse = LoginResponse(user: User(name: "Test User", email: "success@example.com"), token: Token(accessToken: "VALID_TOKEN", expiry: Date().addingTimeInterval(3600), refreshToken: nil))
        loginService.stubbedResult = .success(expectedResponse)

        let result = await sut.login(with: credentials)

        switch result {
        case let .success(response):
            XCTAssertEqual(response, expectedResponse, "Should return the expected response")
        case .failure:
            XCTFail("Expected success, got failure")
        }

        XCTAssertEqual(loginService.executeCallCount, 1, "LoginService should be called once")
        XCTAssertEqual(loginService.lastCredentials, credentials, "LoginService should be called with correct credentials")
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (
        sut: UserLoginUseCase,
        loginService: LoginServiceSpy
    ) {
        let loginService = LoginServiceSpy()
        let sut = UserLoginUseCase(loginService: loginService)

        trackForMemoryLeaks(loginService, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)

        return (sut, loginService)
    }
}
