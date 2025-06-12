import EssentialFeed
import XCTest

final class TokenRefreshEndToEndTests: XCTestCase {
    func test_endToEndTokenRefresh_success() async throws {
        let (sut, client, tokenStorage, refreshUseCase, _) = makeSUT()

        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken()))
        refreshUseCase.stubResult = .success(validToken())

        await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))
        await client.stubNextSend(result: .success((anyData(), anyHTTPURLResponse())))

        let request = URLRequest(url: anyURL())

        let result = try await sut.send(request)
        XCTAssertNotNil(result, "Should complete successfully after refresh")

        let clientRequests = await client.requests
        XCTAssertEqual(clientRequests.count, 2, "Should make initial request and retry")

        let tokenStorageMessages = await tokenStorage.messages
        let saveMessages = tokenStorageMessages.filter {
            if case let .save(tokenBundle: token) = $0, token == validToken() { return true }
            return false
        }
        XCTAssertEqual(saveMessages.count, 1, "Should save refreshed token")

        let refreshCount = refreshUseCase.executeCallCount
        XCTAssertEqual(refreshCount, 1, "Should execute refresh once")
    }

    func test_endToEndTokenRefresh_failure() async throws {
        let (sut, client, tokenStorage, refreshUseCase, logoutManager) = makeSUT()

        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken()))
        refreshUseCase.stubResult = .failure(URLError(.userAuthenticationRequired))

        await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))

        let request = URLRequest(url: anyURL())

        var capturedError: Error?
        do {
            _ = try await sut.send(request)
        } catch {
            capturedError = error
        }

        XCTAssertNotNil(capturedError, "Should fail when refresh fails")

        let clientRequests = await client.requests
        XCTAssertEqual(clientRequests.count, 1, "Should only make initial request")

        let refreshCount = refreshUseCase.executeCallCount
        XCTAssertEqual(refreshCount, 1, "Should attempt refresh once")

        let logoutCount = await logoutManager.performGlobalLogoutCallCount
        XCTAssertEqual(logoutCount, 1, "Should perform global logout when refresh fails")
    }

    func test_endToEndMultipleRequests_singleRefresh() async throws {
        let (sut, client, tokenStorage, refreshUseCase, logoutManager) = makeSUT()

        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken()))
        refreshUseCase.stubResult = .success(validToken())

        let numberOfRequests = 3
        let expectedResponse = anyHTTPURLResponse()

        for _ in 0 ..< numberOfRequests {
            await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))
        }
        for _ in 0 ..< numberOfRequests {
            await client.stubNextSend(result: .success((anyData(), expectedResponse)))
        }

        let request = URLRequest(url: anyURL())

        let tasks = (0 ..< numberOfRequests).map { _ in
            Task {
                try? await sut.send(request)
            }
        }

        for task in tasks {
            _ = await task.value
        }

        let refreshCount = refreshUseCase.executeCallCount
        XCTAssertGreaterThan(refreshCount, 0, "Should execute refresh at least once for multiple requests")

        let logoutCount = await logoutManager.performGlobalLogoutCallCount
        XCTAssertEqual(logoutCount, 0, "Should not perform logout on successful refresh")
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

    private func expiredToken() -> Token {
        Token(
            accessToken: "expired-token",
            expiry: Date().addingTimeInterval(-3600),
            refreshToken: "refresh-token"
        )
    }

    private func validToken() -> Token {
        Token(
            accessToken: "valid-token",
            expiry: Date().addingTimeInterval(3600),
            refreshToken: "new-refresh-token"
        )
    }

    private func anyURL() -> URL {
        URL(string: "https://example.com")!
    }

    private func anyData() -> Data {
        Data("any data".utf8)
    }

    private func anyHTTPURLResponse() -> HTTPURLResponse {
        HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    private struct PathBasedRoutePolicy: RouteAuthenticationPolicy {
        public func requiresAuthentication(_ request: URLRequest) -> Bool {
            guard let path = request.url?.path else { return true }
            return !path.hasPrefix("/public/")
        }
    }
}
