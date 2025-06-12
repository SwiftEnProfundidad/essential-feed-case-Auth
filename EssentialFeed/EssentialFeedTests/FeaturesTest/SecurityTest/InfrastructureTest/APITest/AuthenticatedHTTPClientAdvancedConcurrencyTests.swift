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
        await tokenStorage.completeLoadTokenBundle(with: expiredToken)

        let refreshedToken = Token(
            accessToken: "new-token",
            expiry: Date().addingTimeInterval(3600),
            refreshToken: "new-refresh-token"
        )
        await refreshUseCase.setStubResult(.success(refreshedToken))

        let url = anyURL()
        let request = URLRequest(url: url)
        let numberOfRequests = 10

        let tasks = (0 ..< numberOfRequests).map { _ in
            Task {
                try? await sut.send(request)
            }
        }

        try await Task.sleep(nanoseconds: 100_000_000)

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

        let clientRequests = await client.requests
        XCTAssertEqual(clientRequests.count, numberOfRequests * 2, "Should make initial requests and retries")

        let tokenStorageMessages = await tokenStorage.messages
        let saveCount = tokenStorageMessages.filter {
            if case .save = $0 { return true }
            return false
        }.count
        XCTAssertEqual(saveCount, 1, "Should save token only once")

        XCTAssertEqual(successCount, numberOfRequests, "All requests should succeed after refresh")

        let refreshCount = await refreshUseCase.executeCallCount
        XCTAssertEqual(refreshCount, 1, "Should execute refresh exactly once")
    }

    func test_refreshFailure_triggersGlobalLogout() async throws {
        let (sut, client, tokenStorage, refreshUseCase, logoutManager) = makeSUT()

        let expiredToken = Token(
            accessToken: "expired-token",
            expiry: Date().addingTimeInterval(-3600),
            refreshToken: "refresh-token"
        )
        await tokenStorage.completeLoadTokenBundle(with: expiredToken)

        await refreshUseCase.setStubResult(.failure(URLError(.userAuthenticationRequired)))

        await logoutManager.completePerformGlobalLogout(with: .success(()))

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

        XCTAssertNotNil(capturedError, "Should capture error when refresh fails")

        let refreshCount = await refreshUseCase.executeCallCount
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
        await tokenStorage.completeLoadTokenBundle(with: expiredToken)

        await refreshUseCase.setStubResult(.failure(URLError(.userAuthenticationRequired)))

        await logoutManager.completePerformGlobalLogout(with: .success(()))

        let url = anyURL()
        let request = URLRequest(url: url)
        let numberOfRequests = 5

        let tasks = (0 ..< numberOfRequests).map { _ in
            Task {
                try? await sut.send(request)
            }
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        for index in 0 ..< numberOfRequests {
            await client.complete(with: URLError(.userAuthenticationRequired), at: index)
        }

        for task in tasks {
            _ = await task.value
        }

        let refreshCount = await refreshUseCase.executeCallCount
        XCTAssertEqual(refreshCount, 1, "Should execute refresh exactly once")

        let clientRequests = await client.requests
        XCTAssertEqual(clientRequests.count, numberOfRequests, "Should make all initial requests")

        let logoutCount = await logoutManager.performGlobalLogoutCallCount
        XCTAssertEqual(logoutCount, 1, "Should perform global logout exactly once")
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
