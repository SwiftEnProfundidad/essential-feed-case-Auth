import EssentialFeed
import XCTest

final class AuthUseCaseTests: XCTestCase {
    private var requestStoreSpy: InMemoryPendingRequestStoreSpy<LoginRequest>!
    private var savedRequest: LoginRequest?

    override func setUp() {
        super.setUp()
        requestStoreSpy = InMemoryPendingRequestStoreSpy<LoginRequest>()
        requestStoreSpy.saveAction = { [weak self] request in
            self?.savedRequest = request
        }
    }

    override func tearDown() {
        requestStoreSpy = nil
        savedRequest = nil
        super.tearDown()
    }

    func test_init_doesNotPerformAnyRequest() async {
        let (_, authSpy, _) = makeSUT()
        XCTAssertTrue(authSpy.messages.isEmpty)
    }

    func test_execute_performsAuthentication() async {
        let (sut, authSpy, _) = makeSUT()
        let username = "test@user.com"
        let password = "password123"

        _ = await sut.execute(username: username, password: password)

        XCTAssertEqual(authSpy.messages.count, 1)
        XCTAssertEqual(authSpy.messages[0].username, username)
        XCTAssertEqual(authSpy.messages[0].password, password)
    }

    func test_execute_returnsSuccessOnSuccessfulAuthentication() async {
        let expectedResponse = LoginResponse(token: "a-token")
        let (sut, authSpy, _) = makeSUT()
        authSpy.stubbedResult = .success(expectedResponse)

        let result = await sut.execute(username: "any@test.com", password: "any")

        if case let .success(response) = result {
            XCTAssertEqual(response, expectedResponse)
        } else {
            XCTFail("Expected success, got \(result)")
        }
    }

    func test_execute_returnsFailureOnFailedAuthentication() async {
        let expectedError = LoginError.invalidCredentials
        let (sut, authSpy, _) = makeSUT()
        authSpy.stubbedResult = .failure(expectedError)

        let result = await sut.execute(username: "any@test.com", password: "any")

        if case let .failure(error) = result {
            XCTAssertEqual(error, expectedError)
        } else {
            XCTFail("Expected failure, got \(result)")
        }
    }

    func test_execute_savesRequestOnNetworkError() async {
        let storeSpy = InMemoryPendingRequestStoreSpy<LoginRequest>()
        let anyStore = AnyLoginRequestStore(storeSpy)
        let (sut, authSpy, _) = makeSUT(requestStore: anyStore)

        authSpy.stubbedResult = Result<LoginResponse, LoginError>.failure(LoginError.network)

        let username = "any@test.com"
        let password = "any"

        _ = await sut.execute(username: username, password: password)

        let savedRequests = storeSpy.loadAll()
        XCTAssertEqual(savedRequests.count, 1)
        XCTAssertEqual(savedRequests.first?.username, username)
        XCTAssertEqual(savedRequests.first?.password, password)
    }

    func test_execute_doesNotSaveRequestOnNonNetworkError() async {
        var saveCallCount = 0
        let storeSpy = InMemoryPendingRequestStoreSpy<LoginRequest>()
        storeSpy.saveAction = { _ in saveCallCount += 1 }

        let (sut, authSpy, _) = makeSUT(requestStore: AnyLoginRequestStore(storeSpy))
        authSpy.stubbedResult = .failure(.invalidCredentials)

        _ = await sut.execute(username: "any@test.com", password: "any")

        XCTAssertEqual(saveCallCount, 0)
        XCTAssertTrue(storeSpy.loadAll().isEmpty)
    }

    // MARK: - Refresh Token Tests

    func test_refreshToken_performsTokenRefresh() async {
        let (sut, _, tokenRefreshSpy) = makeSUT()
        let refreshToken = "a-refresh-token"

        _ = await sut.refreshToken(refreshToken: refreshToken)

        XCTAssertEqual(tokenRefreshSpy.messages, [refreshToken])
    }

    func test_refreshToken_returnsSuccessOnSuccessfulTokenRefresh() async {
        let expectedResult = TokenRefreshResult(
            accessToken: "new-access-token",
            refreshToken: "new-refresh-token",
            expiry: Date()
        )
        let (sut, _, tokenRefreshSpy) = makeSUT()
        tokenRefreshSpy.stubbedResult = .success(expectedResult)

        let result = await sut.refreshToken(refreshToken: "any")

        if case let .success(response) = result {
            XCTAssertEqual(response, expectedResult)
        } else {
            XCTFail("Expected success, got \(result)")
        }
    }

    func test_refreshToken_returnsFailureOnFailedTokenRefresh() async {
        let expectedError = TokenRefreshError.invalidRefreshToken
        let (sut, _, tokenRefreshSpy) = makeSUT()
        tokenRefreshSpy.stubbedResult = .failure(expectedError)

        let result = await sut.refreshToken(refreshToken: "invalid-token")

        if case let .failure(error) = result {
            XCTAssertEqual(error, expectedError)
        } else {
            XCTFail("Expected failure, got \(result)")
        }
    }

    // MARK: - Helpers

    private func makeSUT(
        requestStore: AnyLoginRequestStore? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: AuthUseCase, authSpy: AuthServiceSpy, tokenRefreshSpy: TokenRefreshServiceSpy) {
        let authSpy = AuthServiceSpy()
        let tokenRefreshSpy = TokenRefreshServiceSpy()
        let sut = AuthUseCase(
            authenticate: authSpy.authenticate,
            tokenRefreshService: tokenRefreshSpy,
            pendingRequestStore: requestStore
        )
        trackForMemoryLeaks(authSpy, file: file, line: line)
        trackForMemoryLeaks(tokenRefreshSpy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, authSpy, tokenRefreshSpy)
    }
}
