
import EssentialFeed
import XCTest

final class RefreshTokenUseCaseTests: XCTestCase {
    func test_init_doesNotSendRequest() {
        let (_, client, storage, _) = makeSUT()

        XCTAssertTrue(client.requests.isEmpty)
        XCTAssertTrue(storage.messages.isEmpty)
    }

    func test_execute_sendsCorrectRequest() async throws {
			let (sut, client, storage, _) = makeSUT() // parserSpy es tu TokenParserSpy
        let refreshURLFromSUT = URL(string: "https://any-refresh-url.com")!

        storage.completeLoadRefreshToken(with: "any-valid-refresh-token")

        let executeTask = Task { try await sut.execute() }

        let requestRegistered = expectation(description: "Request registered")
        Task {
            var attempts = 0
            let maxAttempts = 100 // Evitar un bucle infinito si algo va muy mal (100 * 10ms = 1s)
            while client.requests.isEmpty && !executeTask.isCancelled && attempts < maxAttempts {
                try? await Task.sleep(nanoseconds: 10_000_000) // 10 ms
                attempts += 1
            }
            
            if !client.requests.isEmpty {
                requestRegistered.fulfill()
            } else {
                requestRegistered.fulfill()
            }
        }

        await fulfillment(of: [requestRegistered], timeout: 1.5) // Aumentamos ligeramente el timeout por si acaso

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

        let receivedToken = try await executeTask.value

        XCTAssertEqual(receivedToken, expectedTokenAfterParsing, "El token recibido no coincide con el esperado del parserSpy.")
        XCTAssertEqual(storage.messages.count, 2, "Se esperaban 2 mensajes en TokenStorageSpy")
			
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
    ) -> (sut: RefreshTokenUseCase, client: HTTPClientSpy, storage: TokenStorageSpy, parser: TokenParserSpy) {
        let client = HTTPClientSpy()
        let storage = TokenStorageSpy()
        let parser = TokenParserSpy()
        let refreshURL = URL(string: "https://any-refresh-url.com")!

        let sut = TokenRefreshService(
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
