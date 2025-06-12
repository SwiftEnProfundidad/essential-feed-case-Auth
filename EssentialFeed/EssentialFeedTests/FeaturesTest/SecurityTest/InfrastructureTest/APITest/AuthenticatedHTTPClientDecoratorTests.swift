import EssentialFeed
import Foundation
import XCTest

@MainActor
final class AuthenticatedHTTPClientDecoratorTests: XCTestCase {
    func test_send_whenRequestIsPublic_doesNotAddAuthorizationHeader() async {
        let (sut, client, _, _, _, _) = makeSUT()
        let publicRequest = URLRequest(url: URL(string: "https://api.example.com/public/feed")!)

        let task = Task {
            _ = try? await sut.send(publicRequest)
        }

        try? await Task.sleep(nanoseconds: 10_000_000)
        await client.complete(with: Data(), response: anyHTTPURLResponse())

        _ = await task.value

        let requests = await client.requests
        XCTAssertEqual(requests.count, 1, "Should forward public requests directly")
        XCTAssertNil(requests.first?.value(forHTTPHeaderField: "Authorization"), "Should not add auth header to public requests")
    }

    func test_send_whenRequestRequiresAuthAndTokenIsValid_addsAuthorizationHeader() async {
        let (sut, client, tokenStorage, _, _, _) = makeSUT()
        let validToken = Token(accessToken: "valid-token", expiry: Date().addingTimeInterval(3600), refreshToken: nil)
        await tokenStorage.completeLoadTokenBundle(with: validToken)

        let protectedRequest = URLRequest(url: URL(string: "https://api.example.com/protected/data")!)

        let task = Task {
            _ = try? await sut.send(protectedRequest)
        }

        try? await Task.sleep(nanoseconds: 10_000_000)

        await client.complete(with: Data(), response: anyHTTPURLResponse())

        _ = await task.value

        let requests = await client.requests
        XCTAssertEqual(requests.count, 1, "Should send one authenticated request")
        XCTAssertEqual(requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer valid-token", "Should add bearer token to protected requests")
    }

    func test_send_whenTokenIsExpired_doesNotAddToken() async {
        let (sut, client, tokenStorage, _, _, _) = makeSUT()
        let expiredToken = Token(accessToken: "expired-token", expiry: Date().addingTimeInterval(-3600), refreshToken: "refresh-token")
        await tokenStorage.completeLoadTokenBundle(with: expiredToken)

        let protectedRequest = URLRequest(url: URL(string: "https://api.example.com/protected/data")!)

        let task = Task {
            _ = try? await sut.send(protectedRequest)
        }

        try? await Task.sleep(nanoseconds: 10_000_000)

        await client.complete(with: Data(), response: anyHTTPURLResponse())

        _ = await task.value

        let requests = await client.requests
        XCTAssertEqual(requests.count, 1, "Should send request")
        XCTAssertNil(requests.first?.value(forHTTPHeaderField: "Authorization"), "Should not add expired token")
    }

    func test_send_whenNoTokenAvailable_sendsRequestWithoutAuth() async {
        let (sut, client, tokenStorage, _, _, _) = makeSUT()
        await tokenStorage.completeLoadTokenBundle(with: nil)

        let protectedRequest = URLRequest(url: URL(string: "https://api.example.com/protected/data")!)

        let task = Task {
            _ = try? await sut.send(protectedRequest)
        }

        try? await Task.sleep(nanoseconds: 10_000_000)

        await client.complete(with: Data(), response: anyHTTPURLResponse())

        _ = await task.value

        let requests = await client.requests
        XCTAssertEqual(requests.count, 1, "Should send request")
        XCTAssertNil(requests.first?.value(forHTTPHeaderField: "Authorization"), "Should not add auth header when no token available")
    }

    func test_send_whenTokenStorageThrowsError_sendsRequestWithoutAuth() async {
        let (sut, client, tokenStorage, _, _, _) = makeSUT()
        await tokenStorage.completeLoadTokenBundle(withError: NSError(domain: "test", code: 1))

        let protectedRequest = URLRequest(url: URL(string: "https://api.example.com/protected/data")!)

        let task = Task {
            _ = try? await sut.send(protectedRequest)
        }

        try? await Task.sleep(nanoseconds: 10_000_000)

        await client.complete(with: Data(), response: anyHTTPURLResponse())

        _ = await task.value

        let requests = await client.requests
        XCTAssertEqual(requests.count, 1, "Should send request")
        XCTAssertNil(requests.first?.value(forHTTPHeaderField: "Authorization"), "Should not add auth header when token loading fails")
    }

    func test_send_whenUnauthorizedErrorOccurs_triggersTokenRefresh() async {
        let (sut, client, tokenStorage, refreshUseCase, _, _) = makeSUT()
        let validToken = Token(accessToken: "valid-token", expiry: Date().addingTimeInterval(3600), refreshToken: "refresh-token")
        await tokenStorage.completeLoadTokenBundle(with: validToken)

        let refreshedToken = Token(accessToken: "refreshed-token", expiry: Date().addingTimeInterval(3600), refreshToken: "refresh-token")
        refreshUseCase.stubResult = .success(refreshedToken)

        let protectedRequest = URLRequest(url: URL(string: "https://api.example.com/protected/data")!)

        let task = Task {
            _ = try? await sut.send(protectedRequest)
        }

        try? await Task.sleep(nanoseconds: 10_000_000)

        await client.complete(with: URLError(.userAuthenticationRequired), at: 0)

        try? await Task.sleep(nanoseconds: 10_000_000)

        await client.complete(with: Data(), response: anyHTTPURLResponse(), at: 1)

        _ = await task.value

        XCTAssertEqual(refreshUseCase.executeCallCount, 1, "Should trigger token refresh on unauthorized error")
        let requests = await client.requests
        XCTAssertEqual(requests.count, 2, "Should retry request after token refresh")
        XCTAssertEqual(requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer refreshed-token", "Should use refreshed token")
    }

    func test_send_whenTokenRefreshFails_performsGlobalLogoutAndThrowsError() async {
        let (sut, client, tokenStorage, refreshUseCase, _, logoutManager) = makeSUT()
        let validToken = Token(accessToken: "valid-token", expiry: Date().addingTimeInterval(3600), refreshToken: "refresh-token")
        await tokenStorage.completeLoadTokenBundle(with: validToken)

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

        await client.complete(with: URLError(.userAuthenticationRequired), at: 0)

        _ = await task.value

        XCTAssertEqual(refreshUseCase.executeCallCount, 1, "Should attempt token refresh")
        let logoutCount = await logoutManager.performGlobalLogoutCallCount
        XCTAssertEqual(logoutCount, 1, "Should perform global logout when refresh fails")
        XCTAssertNotNil(capturedError, "Should capture error when refresh fails")
        XCTAssertTrue(capturedError is SessionError, "Should throw SessionError")
        if case SessionError.globalLogoutRequired = capturedError! {
        } else {
            XCTFail("Should throw globalLogoutRequired error")
        }
    }

    func test_send_whenTokenRefreshFails_throwsError() async {
        let (sut, client, tokenStorage, refreshUseCase, _, _) = makeSUT()
        let validToken = Token(accessToken: "valid-token", expiry: Date().addingTimeInterval(3600), refreshToken: "refresh-token")
        await tokenStorage.completeLoadTokenBundle(with: validToken)

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

        await client.complete(with: URLError(.userAuthenticationRequired), at: 0)

        _ = await task.value

        XCTAssertEqual(refreshUseCase.executeCallCount, 1, "Should attempt token refresh")
        XCTAssertNotNil(capturedError, "Should capture error when refresh fails")
        XCTAssertTrue(capturedError is SessionError, "Should throw SessionError")
    }

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: AuthenticatedHTTPClientDecorator,
        client: HTTPClientSpy,
        tokenStorage: TokenStorageSpy,
        refreshUseCase: RefreshTokenUseCaseSpy,
        sessionManager: SessionManagerSpy,
        logoutManager: SessionLogoutManagerSpy
    ) {
        let client = HTTPClientSpy()
        let tokenStorage = TokenStorageSpy()
        let refreshUseCase = RefreshTokenUseCaseSpy()
        let sessionManager = SessionManagerSpy()
        let logoutManager = SessionLogoutManagerSpy()

        let authHandler = HTTPClientAuthenticationHandlerFactory.make(
            tokenStorage: tokenStorage,
            refreshTokenUseCase: refreshUseCase,
            logoutManager: logoutManager
        )

        let sut = AuthenticatedHTTPClientDecorator(
            client: client,
            authHandler: authHandler
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(client, file: file, line: line)
        trackForMemoryLeaks(tokenStorage, file: file, line: line)
        trackForMemoryLeaks(refreshUseCase, file: file, line: line)
        trackForMemoryLeaks(sessionManager, file: file, line: line)
        trackForMemoryLeaks(logoutManager, file: file, line: line)

        return (sut, client, tokenStorage, refreshUseCase, sessionManager, logoutManager)
    }

    private func anyHTTPURLResponse() -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://any-url.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }
}

@MainActor
final class SessionManagerSpy: SessionManaging {
    private(set) var registerSessionCalls: [(userID: String, token: String, date: Date)] = []

    func registerSession(userID: String, token: String, date: Date) {
        registerSessionCalls.append((userID, token, date))
    }
}
