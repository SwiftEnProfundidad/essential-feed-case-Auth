@testable import EssentialFeed
import XCTest

final class TokenRefreshInterceptorTests: XCTestCase {
    func test_intercept_successfulResponse_returnsResponse() async throws {
        let (sut, refreshUseCase, tokenStorage, nextClient) = makeSUT()
        let request = anyURLRequest()
        let expectedResponse = anyHTTPResponse()
        nextClient.stubbedResult = .success((anyData(), expectedResponse))

        let (_, response) = try await sut.intercept(request, next: nextClient)

        XCTAssertEqual(nextClient.receivedRequests, [request], "Should pass request to next client")
        XCTAssertEqual(response, expectedResponse, "Should return response from next client")
        XCTAssertEqual(refreshUseCase.executeCallCount, 0, "Should not call refresh use case on success")
        XCTAssertEqual(tokenStorage.saveCallCount, 0, "Should not save token on success")
    }

    func test_intercept_nonUnauthorizedError_propagatesError() async {
        let (sut, refreshUseCase, tokenStorage, nextClient) = makeSUT()
        let request = anyURLRequest()
        let nonAuthError = NSError(domain: "test", code: 500, userInfo: nil)
        nextClient.stubbedResult = .failure(nonAuthError)

        do {
            _ = try await sut.intercept(request, next: nextClient)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as NSError, nonAuthError, "Should propagate non-auth errors")
            XCTAssertEqual(refreshUseCase.executeCallCount, 0, "Should not call refresh use case for non-auth errors")
            XCTAssertEqual(tokenStorage.saveCallCount, 0, "Should not save token for non-auth errors")
        }
    }

    func test_intercept_unauthorizedError_attemptsTokenRefreshAndRetry() async throws {
        let (sut, refreshUseCase, tokenStorage, nextClient) = makeSUT()
        let request = anyURLRequest()
        let authError = URLError(.userAuthenticationRequired)
        let refreshedToken = Token(accessToken: "refreshed-token", expiry: Date().addingTimeInterval(3600), refreshToken: "new-refresh")
        let expectedResponse = anyHTTPResponse()

        nextClient.stubbedResults = [
            .failure(authError), // First call fails with 401
            .success((anyData(), expectedResponse)) // Retry succeeds
        ]
        refreshUseCase.stubbedExecuteResult = .success(refreshedToken)
        tokenStorage.stubbedSaveResult = .success(())

        let (_, response) = try await sut.intercept(request, next: nextClient)

        XCTAssertEqual(nextClient.receivedRequests.count, 2, "Should make initial request and retry")
        XCTAssertEqual(refreshUseCase.executeCallCount, 1, "Should call refresh use case once")
        XCTAssertEqual(tokenStorage.saveCallCount, 1, "Should save refreshed token")
        XCTAssertEqual(tokenStorage.receivedTokens, [refreshedToken], "Should save the refreshed token")

        // Check retry request has updated auth header
        let retryRequest = nextClient.receivedRequests[1]
        XCTAssertEqual(retryRequest.value(forHTTPHeaderField: "Authorization"), "Bearer refreshed-token", "Retry request should have new token")
        XCTAssertEqual(response, expectedResponse, "Should return response from retry")
    }

    func test_intercept_unauthorizedErrorAndRefreshFails_propagatesRefreshError() async {
        let (sut, refreshUseCase, tokenStorage, nextClient) = makeSUT()
        let request = anyURLRequest()
        let authError = URLError(.userAuthenticationRequired)
        let refreshError = SessionError.tokenRefreshFailed

        nextClient.stubbedResult = .failure(authError)
        refreshUseCase.stubbedExecuteResult = .failure(refreshError)

        do {
            _ = try await sut.intercept(request, next: nextClient)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? SessionError, refreshError, "Should propagate refresh error")
            XCTAssertEqual(refreshUseCase.executeCallCount, 1, "Should attempt refresh")
            XCTAssertEqual(tokenStorage.saveCallCount, 0, "Should not save token when refresh fails")
        }
    }

    func test_intercept_unauthorizedErrorAndTokenSaveFails_propagatesSaveError() async {
        let (sut, refreshUseCase, tokenStorage, nextClient) = makeSUT()
        let request = anyURLRequest()
        let authError = URLError(.userAuthenticationRequired)
        let refreshedToken = Token(accessToken: "refreshed-token", expiry: Date().addingTimeInterval(3600), refreshToken: nil)
        let saveError = TokenStorageError.encodingFailed

        nextClient.stubbedResult = .failure(authError)
        refreshUseCase.stubbedExecuteResult = .success(refreshedToken)
        tokenStorage.stubbedSaveResult = .failure(saveError)

        do {
            _ = try await sut.intercept(request, next: nextClient)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TokenStorageError, saveError, "Should propagate token save error")
            XCTAssertEqual(refreshUseCase.executeCallCount, 1, "Should attempt refresh")
            XCTAssertEqual(tokenStorage.saveCallCount, 1, "Should attempt to save token")
        }
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (
        sut: TokenRefreshInterceptor,
        refreshUseCase: RefreshTokenUseCaseSpy,
        tokenStorage: TokenStorageSpy,
        nextClient: HTTPClientSpy
    ) {
        let refreshUseCase = RefreshTokenUseCaseSpy()
        let tokenStorage = TokenStorageSpy()
        let nextClient = HTTPClientSpy()
        let sut = TokenRefreshInterceptor(refreshTokenUseCase: refreshUseCase, tokenStorage: tokenStorage)

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(refreshUseCase, file: file, line: line)
        trackForMemoryLeaks(tokenStorage, file: file, line: line)
        trackForMemoryLeaks(nextClient, file: file, line: line)

        return (sut, refreshUseCase, tokenStorage, nextClient)
    }
}

private final class RefreshTokenUseCaseSpy: RefreshTokenUseCase {
    var executeCallCount = 0
    var stubbedExecuteResult: Result<Token, Error> = .failure(SessionError.tokenRefreshFailed)

    func execute() async throws -> Token {
        executeCallCount += 1
        return try stubbedExecuteResult.get()
    }
}
