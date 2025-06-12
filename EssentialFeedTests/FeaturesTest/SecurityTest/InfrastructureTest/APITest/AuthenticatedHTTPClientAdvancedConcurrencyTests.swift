import EssentialFeed
import XCTest

final class AuthenticatedHTTPClientAdvancedConcurrencyTests: XCTestCase {
    func test_concurrentRequests_sharesSingleRefresh() async throws {
        let (sut, client, tokenStorage, refreshUseCase, _) = makeSUT()

        let expiredToken = Token(
            accessToken: "expired-token",
            expiry: Date().addingTimeInterval(-3600),
            refreshToken: "refresh-token"
        )
        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken))
        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken))
        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken))
        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken))
        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken))

        let refreshedToken = Token(
            accessToken: "new-token",
            expiry: Date().addingTimeInterval(3600),
            refreshToken: "new-refresh-token"
        )
        refreshUseCase.stubResult = .success(refreshedToken)

        let url = anyURL()
        let request = URLRequest(url: url)
        let numberOfRequests = 5

        await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))
        await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))
        await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))
        await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))
        await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))

        let expectedResponse = HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
        await client.stubNextSend(result: .success((anyData(), expectedResponse)))
        await client.stubNextSend(result: .success((anyData(), expectedResponse)))
        await client.stubNextSend(result: .success((anyData(), expectedResponse)))
        await client.stubNextSend(result: .success((anyData(), expectedResponse)))
        await client.stubNextSend(result: .success((anyData(), expectedResponse)))

        let tasks = (0 ..< numberOfRequests).map { _ in
            Task {
                try? await sut.send(request)
            }
        }

        var successCount = 0
        for task in tasks {
            if let _ = await task.value {
                successCount += 1
            }
        }

        let clientRequests = await client.requests
        XCTAssertEqual(clientRequests.count, numberOfRequests * 2, "Should make initial requests and retries")

        let tokenStorageMessages = await tokenStorage.messages
        let saveCount = tokenStorageMessages.filter {
            if case .save = $0 { return true }
            return false
        }.count
        XCTAssertGreaterThan(saveCount, 0, "Should save token at least once")

        XCTAssertEqual(successCount, numberOfRequests, "All requests should succeed after refresh")

        let refreshCount = refreshUseCase.executeCallCount
        XCTAssertGreaterThan(refreshCount, 0, "Should execute refresh at least once")
    }

    func test_refreshFailure_triggersGlobalLogout() async throws {
        let (sut, client, tokenStorage, refreshUseCase, logoutManager) = makeSUT()

        let expiredToken = Token(
            accessToken: "expired-token",
            expiry: Date().addingTimeInterval(-3600),
            refreshToken: "refresh-token"
        )
        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken))

        refreshUseCase.stubResult = .failure(URLError(.userAuthenticationRequired))

        await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))

        let url = anyURL()
        let request = URLRequest(url: url)

        var capturedError: Error?
        do {
            _ = try await sut.send(request)
        } catch {
            capturedError = error
        }

        XCTAssertNotNil(capturedError, "Should capture error when refresh fails")

        let refreshCount = refreshUseCase.executeCallCount
        XCTAssertEqual(refreshCount, 1, "Should attempt refresh once")

        let logoutCount = await logoutManager.performGlobalLogoutCallCount
        XCTAssertEqual(logoutCount, 1, "Should perform global logout when refresh fails")
    }

    func test_simultaneousRefreshFailures_onlyOneGlobalLogout() async throws {
        let (sut, client, tokenStorage, refreshUseCase, logoutManager) = makeSUT()

        let expiredToken = Token(
            accessToken: "expired-token",
            expiry: Date().addingTimeInterval(-3600),
            refreshToken: "refresh-token"
        )
        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken))
        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken))
        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken))

        refreshUseCase.stubResult = .failure(URLError(.userAuthenticationRequired))

        await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))
        await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))
        await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))

        let url = anyURL()
        let request = URLRequest(url: url)
        let numberOfRequests = 3

        let tasks = (0 ..< numberOfRequests).map { _ in
            Task {
                try? await sut.send(request)
            }
        }

        for task in tasks {
            _ = await task.value
        }

        let refreshCount = refreshUseCase.executeCallCount
        XCTAssertGreaterThan(refreshCount, 0, "Should execute refresh at least once")

        let clientRequests = await client.requests
        XCTAssertEqual(clientRequests.count, numberOfRequests, "Should make all initial requests")

        let logoutCount = await logoutManager.performGlobalLogoutCallCount
        XCTAssertGreaterThan(logoutCount, 0, "Should perform global logout at least once")
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

        let authHandler = HTTPClientAuthenticationHandlerFactory.make(
            tokenStorage: tokenStorage,
            refreshTokenUseCase: refreshUseCase,
            logoutManager: logoutManager,
            validationStrategy: ExpiryTokenValidationStrategy(),
            routePolicy: PathBasedRoutePolicy()
        )

        let sut = AuthenticatedHTTPClientDecorator(
            client: client,
            authHandler: authHandler
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(client, file: file, line: line)
        trackForMemoryLeaks(tokenStorage, file: file, line: line)
        trackForMemoryLeaks(refreshUseCase, file: file, line: line)
        trackForMemoryLeaks(logoutManager, file: file, line: line)

        return (sut, client, tokenStorage, refreshUseCase, logoutManager)
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
