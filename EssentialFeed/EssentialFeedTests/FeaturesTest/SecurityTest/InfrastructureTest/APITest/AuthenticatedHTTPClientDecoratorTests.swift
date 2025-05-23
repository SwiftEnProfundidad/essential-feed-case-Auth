import EssentialFeed
import XCTest

@MainActor
final class AuthenticatedHTTPClientDecoratorTests: XCTestCase {
    func test_send_whenRequestFailsWithUnauthorizedError_triggersTokenRefresh() async {
        let (sut, client, sessionManager) = makeSUT()
        let unauthorizedError = NSError(domain: "test", code: 401)

        let exp = expectation(description: "Wait for request completion")
        Task {
            _ = try? await sut.send(anyURLRequest())
            exp.fulfill()
        }

        client.complete(with: unauthorizedError)

        await fulfillment(of: [exp], timeout: 1.0)

        XCTAssertEqual(sessionManager.refreshCalls, 1, "Should trigger token refresh")
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (
        sut: AuthenticatedHTTPClientDecorator, client: HTTPClientSpy, sessionManager: SessionManagerSpy
    ) {
        let client = HTTPClientSpy()
        let tokenStore = TokenStoreSpy()
        let authUseCase = AuthUseCaseSpy()
        let sessionManager = SessionManagerSpy()
        let sut = AuthenticatedHTTPClientDecorator(
            client: client,
            tokenStore: tokenStore,
            authUseCase: authUseCase,
            sessionManager: sessionManager
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(client, file: file, line: line)

        return (sut, client, sessionManager)
    }

    private func anyURLRequest() -> URLRequest {
        URLRequest(url: URL(string: "https://any-url.com")!)
    }
}
