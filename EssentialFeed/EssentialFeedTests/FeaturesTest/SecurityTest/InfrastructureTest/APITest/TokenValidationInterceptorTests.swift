@testable import EssentialFeed
import XCTest

final class TokenValidationInterceptorTests: XCTestCase {
    func test_intercept_noTokenAvailable_passesRequestUnmodified() async throws {
        let (sut, tokenStorage, validationStrategy, nextClient) = makeSUT()
        tokenStorage.stubbedLoadResult = .success(nil)
        let request = anyURLRequest()
        let expectedResponse = anyHTTPResponse()
        nextClient.stubbedResult = .success((anyData(), expectedResponse))

        let (_, response) = try await sut.intercept(request, next: nextClient)

        XCTAssertEqual(nextClient.receivedRequests.count, 1, "Should call next client once")
        XCTAssertNil(nextClient.receivedRequests[0].value(forHTTPHeaderField: "Authorization"), "Should not add Authorization header when no token")
        XCTAssertEqual(response, expectedResponse, "Should return response from next client")
    }

    func test_intercept_tokenStorageThrows_passesRequestUnmodified() async throws {
        let (sut, tokenStorage, validationStrategy, nextClient) = makeSUT()
        tokenStorage.stubbedLoadResult = .failure(anyNSError())
        let request = anyURLRequest()
        let expectedResponse = anyHTTPResponse()
        nextClient.stubbedResult = .success((anyData(), expectedResponse))

        let (_, response) = try await sut.intercept(request, next: nextClient)

        XCTAssertEqual(nextClient.receivedRequests.count, 1, "Should call next client once")
        XCTAssertNil(nextClient.receivedRequests[0].value(forHTTPHeaderField: "Authorization"), "Should not add Authorization header when token loading fails")
        XCTAssertEqual(response, expectedResponse, "Should return response from next client")
    }

    func test_intercept_validToken_addsAuthorizationHeader() async throws {
        let (sut, tokenStorage, validationStrategy, nextClient) = makeSUT()
        let token = Token(accessToken: "valid-token", expiry: Date().addingTimeInterval(3600), refreshToken: nil)
        tokenStorage.stubbedLoadResult = .success(token)
        validationStrategy.stubbedIsValid = true
        let request = anyURLRequest()
        let expectedResponse = anyHTTPResponse()
        nextClient.stubbedResult = .success((anyData(), expectedResponse))

        let (_, response) = try await sut.intercept(request, next: nextClient)

        XCTAssertEqual(nextClient.receivedRequests.count, 1, "Should call next client once")
        XCTAssertEqual(nextClient.receivedRequests[0].value(forHTTPHeaderField: "Authorization"), "Bearer valid-token", "Should add Bearer token to Authorization header")
        XCTAssertEqual(response, expectedResponse, "Should return response from next client")
    }

    func test_intercept_invalidToken_passesRequestUnmodified() async throws {
        let (sut, tokenStorage, validationStrategy, nextClient) = makeSUT()
        let token = Token(accessToken: "expired-token", expiry: Date().addingTimeInterval(-3600), refreshToken: nil)
        tokenStorage.stubbedLoadResult = .success(token)
        validationStrategy.stubbedIsValid = false
        let request = anyURLRequest()
        let expectedResponse = anyHTTPResponse()
        nextClient.stubbedResult = .success((anyData(), expectedResponse))

        let (_, response) = try await sut.intercept(request, next: nextClient)

        XCTAssertEqual(nextClient.receivedRequests.count, 1, "Should call next client once")
        XCTAssertNil(nextClient.receivedRequests[0].value(forHTTPHeaderField: "Authorization"), "Should not add Authorization header when token is invalid")
        XCTAssertEqual(response, expectedResponse, "Should return response from next client")
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (
        sut: TokenValidationInterceptor,
        tokenStorage: TokenStorageSpy,
        validationStrategy: TokenValidationStrategySpy,
        nextClient: HTTPClientSpy
    ) {
        let tokenStorage = TokenStorageSpy()
        let validationStrategy = TokenValidationStrategySpy()
        let nextClient = HTTPClientSpy()
        let sut = TokenValidationInterceptor(tokenStorage: tokenStorage, validationStrategy: validationStrategy)

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(tokenStorage, file: file, line: line)
        trackForMemoryLeaks(validationStrategy, file: file, line: line)
        trackForMemoryLeaks(nextClient, file: file, line: line)

        return (sut, tokenStorage, validationStrategy, nextClient)
    }
}

private final class TokenValidationStrategySpy: TokenValidationStrategy {
    var stubbedIsValid = false
    var receivedTokens: [Token] = []

    func isValid(_ token: Token) -> Bool {
        receivedTokens.append(token)
        return stubbedIsValid
    }
}
