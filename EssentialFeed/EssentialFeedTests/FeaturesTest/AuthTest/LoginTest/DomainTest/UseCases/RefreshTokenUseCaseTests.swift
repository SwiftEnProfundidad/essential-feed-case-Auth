import EssentialFeed
import XCTest

final class RefreshTokenUseCaseTests: XCTestCase {
    func test_init_doesNotSendRequest() async {
        let (_, client, storage, _) = makeSUT()

        let clientRequests = await client.requests
        let storageMessages = await storage.messages
        XCTAssertTrue(clientRequests.isEmpty)
        XCTAssertTrue(storageMessages.isEmpty)
    }

    func test_execute_sendsCorrectRequest() async throws {
        let (sut, client, storage, parser) = makeSUT()
        let refreshURLFromSUT = URL(string: "https://any-refresh-url.com")!
        let originalRefreshToken = "any-valid-refresh-token"

        let initialTokenBundle = Token(accessToken: "old-access-token", expiry: Date(), refreshToken: originalRefreshToken)
        await storage.completeLoadTokenBundle(with: initialTokenBundle)

        let executeTask = Task { await sut.refreshToken(refreshToken: "") }

        let requestRegistered = expectation(description: "Request registered")

        Task {
            var attempts = 0
            let maxAttempts = 100
            while !executeTask.isCancelled, await client.requests.isEmpty, attempts < maxAttempts {
                try? await Task.sleep(nanoseconds: 10_000_000)
                attempts += 1
            }
            let clientRequests = await client.requests
            if !clientRequests.isEmpty {
                requestRegistered.fulfill()
            } else if executeTask.isCancelled {
                XCTFail("Execute task was cancelled before request could be made.")
                requestRegistered.fulfill()
            } else if attempts >= maxAttempts {
                XCTFail("Timed out waiting for client to register a request.")
                requestRegistered.fulfill()
            }
        }

        await fulfillment(of: [requestRegistered], timeout: 1.5)

        let clientRequests = await client.requests
        guard let firstRequest = clientRequests.first else {
            XCTFail("No request registered in HTTPClientSpy. executeTask might have failed before making a network call (e.g., due to an error thrown by sut.refreshToken() or client.requests not populated in time).")
            return
        }
        XCTAssertEqual(firstRequest.url, refreshURLFromSUT)
        XCTAssertEqual(firstRequest.httpMethod, "POST")

        let parsedAccessToken = "new-parsed-access-token"
        let parsedRefreshToken = "new-parsed-refresh-token"
        let parsedExpiry = Date().addingTimeInterval(3600)
        let tokenFromParser = Token(accessToken: parsedAccessToken, expiry: parsedExpiry, refreshToken: parsedRefreshToken)

        parser.stubbedToken = tokenFromParser

        let expectedTokenAfterParsingAndSaving = tokenFromParser

        let responseData = Data()
        let httpOkResponse = HTTPURLResponse(url: firstRequest.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!

        await client.complete(with: responseData, response: httpOkResponse, at: 0)

        let receivedResult = await executeTask.value

        switch receivedResult {
        case let .success(result):
            XCTAssertEqual(result.accessToken, expectedTokenAfterParsingAndSaving.accessToken, "Received accessToken does not match")
            XCTAssertEqual(result.refreshToken, parsedRefreshToken, "Result refreshToken should be the new one from the parsed server response")
            XCTAssertEqual(result.expiry, expectedTokenAfterParsingAndSaving.expiry, "Expiry date does not match")
        case let .failure(error):
            XCTFail("Expected success, but failed with error: \(error)")
        }

        let storageMessages = await storage.messages
        XCTAssertEqual(storageMessages.count, 2, "Expected 2 messages in TokenStorageSpy")

        if storageMessages.count == 2 {
            let loadMessage = storageMessages[0]
            let saveMessage = storageMessages[1]
            XCTAssertEqual(loadMessage, TokenStorageSpy.Message.loadTokenBundle)
            XCTAssertEqual(saveMessage, TokenStorageSpy.Message.save(tokenBundle: expectedTokenAfterParsingAndSaving))
        }

        let finalClientRequests = await client.requests
        XCTAssertEqual(finalClientRequests.count, 1)
    }

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
