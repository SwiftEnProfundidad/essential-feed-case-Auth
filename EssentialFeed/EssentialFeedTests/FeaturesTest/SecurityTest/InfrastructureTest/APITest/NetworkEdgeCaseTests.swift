import EssentialFeed
import XCTest

final class NetworkEdgeCaseTests: XCTestCase {
    func test_networkLossDuringRefresh_handlesGracefully() async throws {
        let (sut, client, tokenStorage, refreshUseCase, logoutManager) = makeSUT()

        let expiredToken = Token(
            accessToken: "expired-token",
            expiry: Date().addingTimeInterval(-3600),
            refreshToken: "refresh-token"
        )
        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken))

        refreshUseCase.stubResult = .failure(URLError(.networkConnectionLost))

        await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))

        let url = anyURL()
        let request = URLRequest(url: url)

        var capturedError: Error?
        do {
            _ = try await sut.send(request)
        } catch {
            capturedError = error
        }

        let refreshCount = refreshUseCase.executeCallCount
        XCTAssertEqual(refreshCount, 1, "Should attempt refresh once")
        XCTAssertNotNil(capturedError, "Should capture network error")
        XCTAssertTrue(capturedError is URLError, "Should propagate network error")
        let logoutCount = await logoutManager.performGlobalLogoutCallCount
        XCTAssertEqual(logoutCount, 0, "Should not perform logout on network error")
    }

    func test_networkLossAfterRequestSent_retriesCorrectly() async throws {
        let (sut, client, tokenStorage, refreshUseCase, _) = makeSUT()

        let validToken = Token(
            accessToken: "valid-token",
            expiry: Date().addingTimeInterval(3600),
            refreshToken: "refresh-token"
        )
        await tokenStorage.stubNextLoadTokenBundle(result: .success(validToken))

        await client.stubNextSend(result: .failure(URLError(.networkConnectionLost)))

        let url = anyURL()
        let request = URLRequest(url: url)

        var capturedError: Error?
        do {
            _ = try await sut.send(request)
        } catch {
            capturedError = error
        }

        let clientRequests = await client.requests
        XCTAssertEqual(clientRequests.count, 1, "Should make initial request")
        XCTAssertNotNil(capturedError, "Should capture network error")
        XCTAssertTrue(capturedError is URLError, "Should propagate URLError")
        let refreshCount = refreshUseCase.executeCallCount
        XCTAssertEqual(refreshCount, 0, "Should not attempt refresh on direct network error")
    }

    func test_partialNetworkFailure_degradedMode() async throws {
        let (sut, client, tokenStorage, refreshUseCase, _) = makeSUT()

        let validToken = Token(
            accessToken: "valid-token",
            expiry: Date().addingTimeInterval(3600),
            refreshToken: "refresh-token"
        )
        await tokenStorage.stubNextLoadTokenBundle(result: .success(validToken))

        await client.stubNextSend(result: .failure(URLError(.timedOut)))
        await client.stubNextSend(result: .success((anyData(), anyHTTPURLResponse())))
        await client.stubNextSend(result: .failure(URLError(.networkConnectionLost)))
        await client.stubNextSend(result: .success((anyData(), anyHTTPURLResponse())))
        await client.stubNextSend(result: .failure(URLError(.notConnectedToInternet)))

        let url = anyURL()
        let request = URLRequest(url: url)

        let requestTasks = (0 ..< 5).map { _ in
            Task {
                try? await sut.send(request)
            }
        }

        var successCount = 0
        var errorCount = 0

        for task in requestTasks {
            if await (task.value) != nil {
                successCount += 1
            } else {
                errorCount += 1
            }
        }

        let clientRequests = await client.requests
        XCTAssertEqual(clientRequests.count, 5, "Should make all requests")
        XCTAssertEqual(successCount, 2, "Should succeed for non-network-error responses")
        XCTAssertEqual(errorCount, 3, "Should fail for network errors")
        let refreshCount = refreshUseCase.executeCallCount
        XCTAssertEqual(refreshCount, 0, "Should not attempt refresh for network errors")
    }

    func test_networkFlapping_stabilizesOperation() async throws {
        let (sut, client, tokenStorage, refreshUseCase, _) = makeSUT()

        let expiredToken = Token(
            accessToken: "expired-token",
            expiry: Date().addingTimeInterval(-3600),
            refreshToken: "refresh-token"
        )
        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken))

        let refreshedToken = Token(
            accessToken: "new-token",
            expiry: Date().addingTimeInterval(3600),
            refreshToken: "new-refresh-token"
        )
        refreshUseCase.stubResult = .success(refreshedToken)

        await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))
        await client.stubNextSend(result: .failure(URLError(.networkConnectionLost)))

        let url = anyURL()
        let request = URLRequest(url: url)

        var capturedErrorValue: Error?
        do {
            _ = try await sut.send(request)
        } catch {
            capturedErrorValue = error
        }

        XCTAssertNotNil(capturedErrorValue, "Should have captured an error from sut.send")
        if let capturedURLError = capturedErrorValue as? URLError {
            XCTAssertEqual(capturedURLError.code, .networkConnectionLost, "The final error should be networkConnectionLost")
        } else {
            XCTFail("Captured error was not a URLError: \(String(describing: capturedErrorValue))")
        }

        let refreshCount = refreshUseCase.executeCallCount
        XCTAssertEqual(refreshCount, 1, "Should execute refresh once")
        let clientRequests = await client.requests
        XCTAssertEqual(clientRequests.count, 2, "Should make initial request and one retry after refresh")
    }

    func test_slowNetworkDuringConcurrentRefresh_maintainsConsistency() async throws {
        let (sut, client, tokenStorage, refreshUseCase, _) = makeSUT()

        let expiredToken = Token(
            accessToken: "expired-token",
            expiry: Date().addingTimeInterval(-3600),
            refreshToken: "refresh-token"
        )
        await tokenStorage.stubNextLoadTokenBundle(result: .success(expiredToken))

        let refreshedToken = Token(
            accessToken: "new-token",
            expiry: Date().addingTimeInterval(3600),
            refreshToken: "new-refresh-token"
        )
        refreshUseCase.stubResult = .success(refreshedToken)

        let numberOfRequests = 3
        let expectedResponse = anyHTTPURLResponse()

        for _ in 0 ..< numberOfRequests {
            await client.stubNextSend(result: .failure(URLError(.userAuthenticationRequired)))
        }
        for _ in 0 ..< numberOfRequests {
            await client.stubNextSend(result: .success((anyData(), expectedResponse)))
        }

        let url = anyURL()
        let request = URLRequest(url: url)

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

        XCTAssertEqual(successCount, numberOfRequests, "All requests should eventually succeed")
        let refreshCount = refreshUseCase.executeCallCount
        XCTAssertGreaterThan(refreshCount, 0, "Should execute refresh at least once")
        let clientRequests = await client.requests
        XCTAssertEqual(clientRequests.count, numberOfRequests * 2, "Should make initial requests and retries")
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
