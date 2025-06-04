@testable import EssentialFeed
import XCTest

final class GlobalLogoutInterceptorTests: XCTestCase {
    func test_intercept_successfulResponse_returnsResponse() async throws {
        let (sut, logoutManager, nextClient) = makeSUT()
        let request = anyURLRequest()
        let expectedResponse = anyHTTPResponse()
        nextClient.stubbedResult = .success((anyData(), expectedResponse))

        let (_, response) = try await sut.intercept(request, next: nextClient)

        XCTAssertEqual(nextClient.receivedRequests, [request], "Should pass request to next client")
        XCTAssertEqual(response, expectedResponse, "Should return response from next client")
        XCTAssertEqual(logoutManager.performGlobalLogoutCallCount, 0, "Should not perform logout on success")
    }

    func test_intercept_nonTokenRefreshError_propagatesError() async {
        let (sut, logoutManager, nextClient) = makeSUT()
        let request = anyURLRequest()
        let nonRefreshError = NSError(domain: "test", code: 500, userInfo: nil)
        nextClient.stubbedResult = .failure(nonRefreshError)

        do {
            _ = try await sut.intercept(request, next: nextClient)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as NSError, nonRefreshError, "Should propagate non-refresh errors")
            XCTAssertEqual(logoutManager.performGlobalLogoutCallCount, 0, "Should not perform logout for non-refresh errors")
        }
    }

    func test_intercept_tokenRefreshError_performsGlobalLogoutAndThrowsSessionError() async {
        let (sut, logoutManager, nextClient) = makeSUT()
        let request = anyURLRequest()
        let refreshError = SessionError.tokenRefreshFailed
        nextClient.stubbedResult = .failure(refreshError)
        logoutManager.stubbedPerformGlobalLogoutResult = .success(())

        do {
            _ = try await sut.intercept(request, next: nextClient)
            XCTFail("Expected SessionError.globalLogoutRequired to be thrown")
        } catch {
            XCTAssertEqual(error as? SessionError, .globalLogoutRequired, "Should throw globalLogoutRequired after logout")
            XCTAssertEqual(logoutManager.performGlobalLogoutCallCount, 1, "Should perform global logout")
        }
    }

    func test_intercept_tokenRefreshErrorAndLogoutFails_propagatesLogoutError() async {
        let (sut, logoutManager, nextClient) = makeSUT()
        let request = anyURLRequest()
        let refreshError = SessionError.tokenRefreshFailed
        let logoutError = NSError(domain: "logout", code: 1, userInfo: nil)
        nextClient.stubbedResult = .failure(refreshError)
        logoutManager.stubbedPerformGlobalLogoutResult = .failure(logoutError)

        do {
            _ = try await sut.intercept(request, next: nextClient)
            XCTFail("Expected logout error to be thrown")
        } catch {
            XCTAssertEqual(error as NSError, logoutError, "Should propagate logout error")
            XCTAssertEqual(logoutManager.performGlobalLogoutCallCount, 1, "Should attempt global logout")
        }
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (
        sut: GlobalLogoutInterceptor,
        logoutManager: SessionLogoutManagerSpy,
        nextClient: HTTPClientSpy
    ) {
        let logoutManager = SessionLogoutManagerSpy()
        let nextClient = HTTPClientSpy()
        let sut = GlobalLogoutInterceptor(logoutManager: logoutManager)

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(logoutManager, file: file, line: line)
        trackForMemoryLeaks(nextClient, file: file, line: line)

        return (sut, logoutManager, nextClient)
    }
}

private final class SessionLogoutManagerSpy: SessionLogoutManager {
    var performGlobalLogoutCallCount = 0
    var stubbedPerformGlobalLogoutResult: Result<Void, Error> = .success(())

    func performGlobalLogout() async throws {
        performGlobalLogoutCallCount += 1
        try stubbedPerformGlobalLogoutResult.get()
    }
}
