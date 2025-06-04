import EssentialFeed
import XCTest

@MainActor
final class AuthenticatedHTTPClientDecoratorTests: XCTestCase {
    func test_send_whenRequestIsPublic_doesNotAddAuthorizationHeader() async {
        let (sut, client, _, _, _) = makeSUT()
        let publicRequest = URLRequest(url: URL(string: "https://api.example.com/public/feed")!)

        let task = Task {
            _ = try? await sut.send(publicRequest)
        }

        try? await Task.sleep(nanoseconds: 10_000_000)
        client.complete(with: Data(), response: anyHTTPURLResponse())

        _ = await task.value

        XCTAssertEqual(client.requests.count, 1, "Should forward public requests directly")
        XCTAssertNil(client.requests.first?.value(forHTTPHeaderField: "Authorization"), "Should not add auth header to public requests")
    }

    func test_send_whenRequestRequiresAuthAndTokenIsValid_addsAuthorizationHeader() async {
        let (sut, client, tokenStorage, _, _) = makeSUT()
        let validToken = Token(accessToken: "valid-token", expiry: Date().addingTimeInterval(3600), refreshToken: nil)
        tokenStorage.completeLoadTokenBundle(with: validToken)

        let protectedRequest = URLRequest(url: URL(string: "https://api.example.com/protected/data")!)

        let task = Task {
            _ = try? await sut.send(protectedRequest)
        }

        try? await Task.sleep(nanoseconds: 10_000_000)

        client.complete(with: Data(), response: anyHTTPURLResponse())

        _ = await task.value

        XCTAssertEqual(client.requests.count, 1, "Should send one authenticated request")
        XCTAssertEqual(client.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer valid-token", "Should add bearer token to protected requests")
    }

    func test_send_whenTokenIsExpired_doesNotAddToken() async {
        let (sut, client, tokenStorage, _, _) = makeSUT()
        let expiredToken = Token(accessToken: "expired-token", expiry: Date().addingTimeInterval(-3600), refreshToken: "refresh-token")
        tokenStorage.completeLoadTokenBundle(with: expiredToken)

        let protectedRequest = URLRequest(url: URL(string: "https://api.example.com/protected/data")!)

        let task = Task {
            _ = try? await sut.send(protectedRequest)
        }

        try? await Task.sleep(nanoseconds: 10_000_000)

        client.complete(with: Data(), response: anyHTTPURLResponse())

        _ = await task.value

        XCTAssertEqual(client.requests.count, 1, "Should send request")
        XCTAssertNil(client.requests.first?.value(forHTTPHeaderField: "Authorization"), "Should not add expired token")
    }

    func test_send_whenNoTokenAvailable_sendsRequestWithoutAuth() async {
        let (sut, client, tokenStorage, _, _) = makeSUT()
        tokenStorage.completeLoadTokenBundle(with: nil)

        let protectedRequest = URLRequest(url: URL(string: "https://api.example.com/protected/data")!)

        let task = Task {
            _ = try? await sut.send(protectedRequest)
        }

        try? await Task.sleep(nanoseconds: 10_000_000)

        client.complete(with: Data(), response: anyHTTPURLResponse())

        _ = await task.value

        XCTAssertEqual(client.requests.count, 1, "Should send request")
        XCTAssertNil(client.requests.first?.value(forHTTPHeaderField: "Authorization"), "Should not add auth header when no token available")
    }

    func test_send_whenTokenStorageThrowsError_sendsRequestWithoutAuth() async {
        let (sut, client, tokenStorage, _, _) = makeSUT()
        tokenStorage.completeLoadTokenBundle(withError: NSError(domain: "test", code: 1))

        let protectedRequest = URLRequest(url: URL(string: "https://api.example.com/protected/data")!)

        let task = Task {
            _ = try? await sut.send(protectedRequest)
        }

        try? await Task.sleep(nanoseconds: 10_000_000)

        client.complete(with: Data(), response: anyHTTPURLResponse())

        _ = await task.value

        XCTAssertEqual(client.requests.count, 1, "Should send request")
        XCTAssertNil(client.requests.first?.value(forHTTPHeaderField: "Authorization"), "Should not add auth header when token loading fails")
    }

    func test_send_whenUnauthorizedErrorOccurs_triggersTokenRefresh() async {
        let (sut, client, tokenStorage, refreshUseCase, _) = makeSUT()
        let validToken = Token(accessToken: "valid-token", expiry: Date().addingTimeInterval(3600), refreshToken: "refresh-token")
        tokenStorage.completeLoadTokenBundle(with: validToken)

        let refreshedToken = Token(accessToken: "refreshed-token", expiry: Date().addingTimeInterval(3600), refreshToken: "refresh-token")
        refreshUseCase.stubResult = .success(refreshedToken)

        let protectedRequest = URLRequest(url: URL(string: "https://api.example.com/protected/data")!)

        let task = Task {
            _ = try? await sut.send(protectedRequest)
        }

        try? await Task.sleep(nanoseconds: 10_000_000)

        client.complete(with: URLError(.userAuthenticationRequired), at: 0)

        try? await Task.sleep(nanoseconds: 10_000_000)

        client.complete(with: Data(), response: anyHTTPURLResponse(), at: 1)

        _ = await task.value

        XCTAssertEqual(refreshUseCase.executeCallCount, 1, "Should trigger token refresh on unauthorized error")
        XCTAssertEqual(client.requests.count, 2, "Should retry request after token refresh")
        XCTAssertEqual(client.requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer refreshed-token", "Should use refreshed token")
    }

    func test_send_whenTokenRefreshFails_throwsError() async {
        let (sut, client, tokenStorage, refreshUseCase, _) = makeSUT()
        let validToken = Token(accessToken: "valid-token", expiry: Date().addingTimeInterval(3600), refreshToken: "refresh-token")
        tokenStorage.completeLoadTokenBundle(with: validToken)

        refreshUseCase.stubResult = .failure(SessionError.tokenRefreshFailed)

        let protectedRequest = URLRequest(url: URL(string: "https://api.example.com/protected/data")!)

        var capturedError: Error?
        let task = Task {
            do {
                _ = try await sut.send(protectedRequest)
            } catch {
                capturedError = error
            }
        }

        try? await Task.sleep(nanoseconds: 10_000_000)

        client.complete(with: URLError(.userAuthenticationRequired), at: 0)

        _ = await task.value

        XCTAssertEqual(refreshUseCase.executeCallCount, 1, "Should attempt token refresh")
        XCTAssertNotNil(capturedError, "Should capture error when refresh fails")
        XCTAssertTrue(capturedError is SessionError, "Should throw SessionError")
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: AuthenticatedHTTPClientDecorator,
        client: HTTPClientSpy,
        tokenStorage: TokenStorageSpy,
        refreshUseCase: RefreshTokenUseCaseSpy,
        sessionManager: SessionManagerSpy
    ) {
        let client = HTTPClientSpy()
        let tokenStorage = TokenStorageSpy()
        let refreshUseCase = RefreshTokenUseCaseSpy()
        let sessionManager = SessionManagerSpy()

        let sut = AuthenticatedHTTPClientDecorator(
            client: client,
            tokenStorage: tokenStorage,
            refreshTokenUseCase: refreshUseCase,
            sessionManager: sessionManager
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(client, file: file, line: line)
        trackForMemoryLeaks(tokenStorage, file: file, line: line)
        trackForMemoryLeaks(refreshUseCase, file: file, line: line)
        trackForMemoryLeaks(sessionManager, file: file, line: line)

        return (sut, client, tokenStorage, refreshUseCase, sessionManager)
    }

    private func anyHTTPURLResponse() -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://any-url.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }
}

// MARK: - Test Doubles

final class RefreshTokenUseCaseSpy: RefreshTokenUseCase {
    private(set) var executeCallCount = 0
    var stubResult: Result<Token, Error> = .failure(SessionError.tokenRefreshFailed)

    func execute() async throws -> Token {
        executeCallCount += 1
        switch stubResult {
        case let .success(token):
            return token
        case let .failure(error):
            throw error
        }
    }
}

@MainActor
final class SessionManagerSpy: SessionManaging {
    private(set) var registerSessionCalls: [(userID: String, token: String, date: Date)] = []

    func registerSession(userID: String, token: String, date: Date) {
        registerSessionCalls.append((userID, token, date))
    }
}
