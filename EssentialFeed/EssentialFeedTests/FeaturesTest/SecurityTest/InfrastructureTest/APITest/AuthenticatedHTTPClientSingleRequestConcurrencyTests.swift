import EssentialFeed
import XCTest

final class AuthenticatedHTTPClientSingleRequestConcurrencyTests: XCTestCase {
    func test_oneRequestWithExpiredToken_triggersRefreshRetriesAndSucceeds() async throws {
        let (sut, client, tokenStorage, refreshUseCase, logoutManager) = makeSUT()

        let expiredToken = Token(
            accessToken: "expired-access-token",
            expiry: Date().addingTimeInterval(-3600),
            refreshToken: "valid-refresh-token"
        )
        let refreshedAccessToken = "new-access-token"
        let refreshedRefreshToken = "new-refresh-token"
        let refreshedToken = Token(
            accessToken: refreshedAccessToken,
            expiry: Date().addingTimeInterval(3600),
            refreshToken: refreshedRefreshToken
        )

        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken))
        await refreshUseCase.setStubResult(.success(refreshedToken))
        await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))
        let expectedData = Data("success data".utf8)
        let expectedResponse = HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
        await client.stubNextSend(result: .success((expectedData, expectedResponse)))

        let request = URLRequest(url: anyURL())

        let (receivedData, receivedResponse) = try await sut.send(request)

        let executeCount = await refreshUseCase.executeCallCount
        XCTAssertEqual(executeCount, 1, "RefreshUseCase should be called exactly once.")

        let storageMessages = await tokenStorage.messages
        XCTAssertEqual(storageMessages.count, 2, "TokenStorage should have two messages: load and save.")
        XCTAssertEqual(storageMessages[0], .loadTokenBundle, "First message to TokenStorage should be to load the token.")
        guard case let .save(savedTokenBundle) = storageMessages[1] else {
            XCTFail("Second message to TokenStorage should be to save the token. Got \(storageMessages[1]) instead.")
            return
        }
        XCTAssertEqual(savedTokenBundle.accessToken, refreshedAccessToken, "Saved access token should be the new one.")
        XCTAssertEqual(savedTokenBundle.refreshToken, refreshedRefreshToken, "Saved refresh token should be the new one.")

        let clientRequests = await client.requests
        XCTAssertEqual(clientRequests.count, 2, "HTTPClient should have received two requests: initial attempt and retry.")

        XCTAssertEqual(receivedData, expectedData, "Received data should be the success data from the retried request.")
        XCTAssertEqual(receivedResponse.url, expectedResponse.url, "Received response URL should match.")
        XCTAssertEqual(receivedResponse.statusCode, expectedResponse.statusCode, "Received response status code should match.")

        let logoutCallCount = await logoutManager.performGlobalLogoutCallCount
        XCTAssertEqual(logoutCallCount, 0, "LogoutManager should not be called.")
    }

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: AuthenticatedHTTPClientDecorator,
        client: HTTPClientSpy,
        tokenStorage: TokenStorageSpy,
        refreshUseCase: RefreshTokenUseCaseSpy,
        logoutManager: SessionLogoutManagerSpy
    ) {
        let client = HTTPClientSpy()
        let tokenStorage = TokenStorageSpy()
        let refreshUseCase = RefreshTokenUseCaseSpy()
        let logoutManager = SessionLogoutManagerSpy()

        let sut = AuthenticatedHTTPClientDecorator(
            client: client,
            tokenStorage: tokenStorage,
            refreshTokenUseCase: refreshUseCase,
            logoutManager: logoutManager,
            validationStrategy: ExpiryTokenValidationStrategy(),
            routePolicy: PathBasedRoutePolicy()
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(client, file: file, line: line)
        trackForMemoryLeaks(tokenStorage, file: file, line: line)
        trackForMemoryLeaks(refreshUseCase, file: file, line: line)
        trackForMemoryLeaks(logoutManager, file: file, line: line)

        return (sut, client, tokenStorage, refreshUseCase, logoutManager)
    }

    private func anyURL() -> URL {
        URL(string: "https://any-url.com")!
    }

    private actor RefreshTokenUseCaseSpy: RefreshTokenUseCase {
        private var _executeCallCount = 0
        private var _stubResult: Result<Token, Error>?

        public var executeCallCount: Int {
            _executeCallCount
        }

        public func setStubResult(_ result: Result<Token, Error>) {
            _stubResult = result
        }

        public func execute() async throws -> Token {
            _executeCallCount += 1
            guard let result = _stubResult else {
                fatalError("Stubbed result not set for RefreshTokenUseCaseSpy")
            }
            switch result {
            case let .success(token):
                return token
            case let .failure(error):
                throw error
            }
        }
    }

    private struct PathBasedRoutePolicy: RouteAuthenticationPolicy {
        public func requiresAuthentication(_ request: URLRequest) -> Bool {
            guard let path = request.url?.path else { return true }
            return !path.hasPrefix("/public/")
        }
    }
}
