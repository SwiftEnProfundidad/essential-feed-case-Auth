import EssentialFeed
import XCTest

final class TokenRefreshEndToEndTests: XCTestCase {
    func test_endToEndTokenRefresh_success() async throws {
        let (sut, client, tokenStorage, refreshUseCase, _) = makeSUT()

        await tokenStorage.completeLoadTokenBundle(with: expiredToken())
        await refreshUseCase.setStubResult(.success(validToken()))

        let request = URLRequest(url: anyURL())

        let requestTask = Task {
            try? await sut.send(request)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        await client.complete(with: URLError(.userAuthenticationRequired), at: 0)

        try await Task.sleep(nanoseconds: 100_000_000)

        let clientRequests = await client.requests
        XCTAssertEqual(clientRequests.count, 1, "Should make initial request")

        let tokenStorageMessages = await tokenStorage.messages
        let saveMessages = tokenStorageMessages.filter {
            if case let .save(tokenBundle: token) = $0, token == validToken() { return true }
            return false
        }
        XCTAssertEqual(saveMessages.count, 1, "Should save refreshed token")

        await client.complete(with: anyData(), response: anyHTTPURLResponse(), at: 1)

        let result = await requestTask.value
        XCTAssertNotNil(result, "Should complete successfully after refresh")

        let refreshCount = await refreshUseCase.executeCallCount
        XCTAssertEqual(refreshCount, 1, "Should execute refresh once")
    }

    func test_endToEndTokenRefresh_failure() async throws {
        let (sut, client, tokenStorage, refreshUseCase, logoutManager) = makeSUT()

        await tokenStorage.completeLoadTokenBundle(with: expiredToken())
        await refreshUseCase.setStubResult(.failure(URLError(.userAuthenticationRequired)))

        let request = URLRequest(url: anyURL())

        let requestTask = Task {
            try? await sut.send(request)
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        await client.complete(with: URLError(.userAuthenticationRequired), at: 0)

        let result = await requestTask.value
        XCTAssertNil(result, "Should fail when refresh fails")

        let clientRequests = await client.requests
        XCTAssertEqual(clientRequests.count, 1, "Should only make initial request")

        let refreshCount = await refreshUseCase.executeCallCount
        XCTAssertEqual(refreshCount, 1, "Should attempt refresh once")

        await logoutManager.completePerformGlobalLogout(with: .success(()))

        try await Task.sleep(nanoseconds: 50_000_000)

        let logoutCount = await logoutManager.performGlobalLogoutCallCount
        XCTAssertEqual(logoutCount, 1, "Should perform global logout when refresh fails")
    }

    func test_endToEndMultipleRequests_singleRefresh() async throws {
        let (sut, client, tokenStorage, refreshUseCase, logoutManager) = makeSUT()

        await tokenStorage.completeLoadTokenBundle(with: expiredToken())
        await refreshUseCase.setStubResult(.success(validToken()))

        let request = URLRequest(url: anyURL())
        let numberOfRequests = 3

        let tasks = (0 ..< numberOfRequests).map { _ in
            Task {
                try? await sut.send(request)
            }
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        for index in 0 ..< numberOfRequests {
            await client.complete(with: URLError(.userAuthenticationRequired), at: index)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        for index in numberOfRequests ..< (numberOfRequests * 2) {
            await client.complete(with: anyData(), response: anyHTTPURLResponse(), at: index)
        }

        for task in tasks {
            _ = await task.value
        }

        let refreshCount = await refreshUseCase.executeCallCount
        XCTAssertEqual(refreshCount, 1, "Should execute refresh exactly once for multiple requests")

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
