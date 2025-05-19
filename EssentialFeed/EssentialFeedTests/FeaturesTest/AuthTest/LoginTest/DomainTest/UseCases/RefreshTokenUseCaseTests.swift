import EssentialFeed
import XCTest

final class RefreshTokenUseCaseTests: XCTestCase {
    func test_init_doesNotSendRequest() {
        let (_, client, storage, _) = makeSUT()

        XCTAssertTrue(client.requests.isEmpty)
        XCTAssertTrue(storage.messages.isEmpty)
    }

    func test_execute_sendsCorrectRequest() async throws {
        let (sut, client, storage, _) = makeSUT()
        let refreshURLFromSUT = URL(string: "https://any-refresh-url.com")!

        storage.completeLoadRefreshToken(with: "any-valid-refresh-token")

        let executeTask = Task { await sut.refreshToken(refreshToken: "") }
        let requestRegistered = expectation(description: "Request registered")

        Task {
            var attempts = 0
            let maxAttempts = 100
            while client.requests.isEmpty, !executeTask.isCancelled, attempts < maxAttempts {
                try? await Task.sleep(nanoseconds: 10_000_000)
                attempts += 1
            }

            requestRegistered.fulfill()
        }

        await fulfillment(of: [requestRegistered], timeout: 1.5)

        guard let firstRequest = client.requests.first else {
            XCTFail("No request registered in HTTPClientSpy. executeTask might have failed before making a network call (e.g., due to an error thrown by sut.execute()).")
            return
        }
        XCTAssertEqual(firstRequest.url, refreshURLFromSUT)
        XCTAssertEqual(firstRequest.httpMethod, "POST")

        let expectedTokenAfterParsing = Token(value: "any-access-token", expiry: Date().addingTimeInterval(3600))

        let responseData = Data()
        let httpOkResponse = HTTPURLResponse(url: firstRequest.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client.complete(with: responseData, response: httpOkResponse, at: 0)

        let receivedResult = await executeTask.value

        switch receivedResult {
        case let .success(result):
            XCTAssertEqual(result.accessToken, expectedTokenAfterParsing.value, "Received accessToken does not match")
            let dateTolerance: TimeInterval = 2.0
            XCTAssertLessThan(abs(result.expiry.timeIntervalSince(expectedTokenAfterParsing.expiry)), dateTolerance, "Expiry date does not match (tolerance \(dateTolerance)s)")
        case let .failure(error):
            XCTFail("Expected success, but failed with error: \(error)")
        }

        XCTAssertEqual(storage.messages.count, 2, "Expected 2 messages in TokenStorageSpy")

        if storage.messages.count == 2 {
            XCTAssertEqual(storage.messages[0], .loadRefreshToken)
            XCTAssertEqual(storage.messages[1], .save(expectedTokenAfterParsing))
        }

        XCTAssertEqual(client.requests.count, 1)
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #file,
        line: UInt = #line
    ) -> (sut: TokenRefreshService, client: HTTPClientSpy, storage: TokenStorageSpy, parser: TokenParserSpy) {
        let client = HTTPClientSpy()
        let storage = TokenStorageSpy()
        let parser = TokenParserSpy()
        let refreshURL = URL(string: "https://any-refresh-url.com")!

        let sut = RemoteTokenRefreshService(
            httpClient: client,
            tokenStorage: storage,
            tokenParser: parser,
            refreshURL: refreshURL
        )

        trackForMemoryLeaks(client, file: file, line: line)
        trackForMemoryLeaks(storage, file: file, line: line)
        trackForMemoryLeaks(parser, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, client, storage, parser)
    }
}
