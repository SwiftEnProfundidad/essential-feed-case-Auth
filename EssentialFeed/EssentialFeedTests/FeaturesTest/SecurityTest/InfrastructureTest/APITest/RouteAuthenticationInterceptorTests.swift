@testable import EssentialFeed
import XCTest

final class RouteAuthenticationInterceptorTests: XCTestCase {
    func test_intercept_requestNotRequiringAuth_passesToNext() async throws {
        let (sut, routePolicy, nextClient) = makeSUT()
        routePolicy.stubbedRequiresAuth = false
        let request = anyURLRequest()
        let expectedResponse = anyHTTPResponse()
        nextClient.stubbedResult = .success((anyData(), expectedResponse))

        let (_, response) = try await sut.intercept(request, next: nextClient)

        XCTAssertEqual(nextClient.receivedRequests, [request], "Should pass request to next client when auth not required")
        XCTAssertEqual(response, expectedResponse, "Should return response from next client")
    }

    func test_intercept_requestRequiringAuth_passesToNext() async throws {
        let (sut, routePolicy, nextClient) = makeSUT()
        routePolicy.stubbedRequiresAuth = true
        let request = anyURLRequest()
        let expectedResponse = anyHTTPResponse()
        nextClient.stubbedResult = .success((anyData(), expectedResponse))

        let (_, response) = try await sut.intercept(request, next: nextClient)

        XCTAssertEqual(nextClient.receivedRequests, [request], "Should pass request to next client when auth is required")
        XCTAssertEqual(response, expectedResponse, "Should return response from next client")
    }

    func test_intercept_nextClientThrows_propagatesError() async {
        let (sut, routePolicy, nextClient) = makeSUT()
        routePolicy.stubbedRequiresAuth = true
        let request = anyURLRequest()
        let expectedError = anyNSError()
        nextClient.stubbedResult = .failure(expectedError)

        do {
            _ = try await sut.intercept(request, next: nextClient)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as NSError, expectedError, "Should propagate error from next client")
        }
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (
        sut: RouteAuthenticationInterceptor,
        routePolicy: RouteAuthenticationPolicySpy,
        nextClient: HTTPClientSpy
    ) {
        let routePolicy = RouteAuthenticationPolicySpy()
        let nextClient = HTTPClientSpy()
        let sut = RouteAuthenticationInterceptor(routePolicy: routePolicy)

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(routePolicy, file: file, line: line)
        trackForMemoryLeaks(nextClient, file: file, line: line)

        return (sut, routePolicy, nextClient)
    }
}

private final class RouteAuthenticationPolicySpy: RouteAuthenticationPolicy {
    var stubbedRequiresAuth = false
    var receivedRequests: [URLRequest] = []

    func requiresAuthentication(_ request: URLRequest) -> Bool {
        receivedRequests.append(request)
        return stubbedRequiresAuth
    }
}
