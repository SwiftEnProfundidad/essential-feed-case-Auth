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
        await tokenStorage.completeLoadTokenBundle(with: expiredToken)

        await refreshUseCase.setStubResult(.failure(URLError(.networkConnectionLost)))

        let url = anyURL()
        let request = URLRequest(url: url)

        var capturedError: Error?
        let requestTask = Task {
            do {
                _ = try await sut.send(request)
            } catch {
                capturedError = error
            }
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        await client.complete(with: URLError(.userAuthenticationRequired), at: 0)

        _ = await requestTask.value

        let refreshCount = await refreshUseCase.executeCallCount
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
        await tokenStorage.completeLoadTokenBundle(with: validToken)

        let url = anyURL()
        let request = URLRequest(url: url)

        var capturedError: Error?
        let requestTask = Task {
            do {
                _ = try await sut.send(request)
            } catch {
                capturedError = error
            }
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        await client.complete(with: URLError(.networkConnectionLost), at: 0)

        _ = await requestTask.value

        let clientRequests = await client.requests
        XCTAssertEqual(clientRequests.count, 1, "Should make initial request")
        XCTAssertNotNil(capturedError, "Should capture network error")
        XCTAssertTrue(capturedError is URLError, "Should propagate URLError")
        let refreshCount = await refreshUseCase.executeCallCount
        XCTAssertEqual(refreshCount, 0, "Should not attempt refresh on direct network error")
    }

    func test_partialNetworkFailure_degradedMode() async throws {
        let (sut, client, tokenStorage, refreshUseCase, _) = makeSUT()

        let validToken = Token(
            accessToken: "valid-token",
            expiry: Date().addingTimeInterval(3600),
            refreshToken: "refresh-token"
        )
        await tokenStorage.completeLoadTokenBundle(with: validToken)

        let url = anyURL()
        let request = URLRequest(url: url)

        let requestTasks = (0 ..< 5).map { _ in
            Task {
                try? await sut.send(request)
            }
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        await client.complete(with: URLError(.timedOut), at: 0)
        await client.complete(with: anyData(), response: anyHTTPURLResponse(), at: 1)
        await client.complete(with: URLError(.networkConnectionLost), at: 2)
        await client.complete(with: anyData(), response: anyHTTPURLResponse(), at: 3)
        await client.complete(with: URLError(.notConnectedToInternet), at: 4)

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
        let refreshCount = await refreshUseCase.executeCallCount
        XCTAssertEqual(refreshCount, 0, "Should not attempt refresh for network errors")
    }

    func test_networkFlapping_stabilizesOperation() async throws {
        let (sut, client, tokenStorage, refreshUseCase, _) = makeSUT()

        let expiredToken = Token(
            accessToken: "expired-token",
            expiry: Date().addingTimeInterval(-3600),
            refreshToken: "refresh-token"
        )
        await tokenStorage.completeLoadTokenBundle(with: expiredToken)

        let refreshedToken = Token(
            accessToken: "new-token",
            expiry: Date().addingTimeInterval(3600),
            refreshToken: "new-refresh-token"
        )
        await refreshUseCase.setStubResult(.success(refreshedToken))

        let url = anyURL()
        let request = URLRequest(url: url)

        var capturedErrorValue: Error? = nil
        let requestTask = Task {
            do {
                _ = try await sut.send(request)
            } catch {
                capturedErrorValue = error
            }
        }

        try await Task.sleep(nanoseconds: 30_000_000)

        await client.complete(with: URLError(.userAuthenticationRequired), at: 0)

        try await Task.sleep(nanoseconds: 30_000_000)

        let networkError = URLError(.networkConnectionLost)
        await client.complete(with: networkError, at: 1)

        _ = await requestTask.value

        XCTAssertNotNil(capturedErrorValue, "Should have captured an error from sut.send")
        if let capturedURLError = capturedErrorValue as? URLError {
            XCTAssertEqual(capturedURLError.code, .networkConnectionLost, "The final error should be networkConnectionLost")
        } else {
            XCTFail("Captured error was not a URLError: \(String(describing: capturedErrorValue))")
        }

        let refreshCount = await refreshUseCase.executeCallCount
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
        await tokenStorage.completeLoadTokenBundle(with: expiredToken)

        let refreshedToken = Token(
            accessToken: "new-token",
            expiry: Date().addingTimeInterval(3600),
            refreshToken: "new-refresh-token"
        )
        await refreshUseCase.setStubResult(.success(refreshedToken))

        let url = anyURL()
        let request = URLRequest(url: url)
        let numberOfRequests = 6

        let tasks = (0 ..< numberOfRequests).map { _ in
            Task {
                try? await sut.send(request)
            }
        }

        try await Task.sleep(nanoseconds: 20_000_000)

        for index in 0 ..< numberOfRequests {
            await client.complete(with: URLError(.userAuthenticationRequired), at: index)
        }

        try await Task.sleep(nanoseconds: 200_000_000)

        for index in numberOfRequests ..< (numberOfRequests * 2) {
            await client.complete(with: anyData(), response: anyHTTPURLResponse(), at: index)
        }

        var successCount = 0
        for task in tasks {
            if let _ = await task.value {
                successCount += 1
            }
        }

        XCTAssertEqual(successCount, numberOfRequests, "All requests should eventually succeed")
        let refreshCount = await refreshUseCase.executeCallCount
        XCTAssertEqual(refreshCount, 1, "Should execute refresh exactly once despite slow network")
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
        URL(string: "https://example.com")!
    }

    private func anyData() -> Data {
        Data("any data".utf8)
    }

    private func anyHTTPURLResponse() -> HTTPURLResponse {
        HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
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
