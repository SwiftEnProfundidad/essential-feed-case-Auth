import XCTest
import EssentialFeed

class RefreshTokenUseCaseTests: XCTestCase {
	func test_init_noSideEffects() {
		let (client, storage, _) = makeSUT()
		XCTAssertTrue(client.requests.isEmpty)
		XCTAssertTrue(storage.messages.isEmpty)
	}
	
	func test_execute_sendsCorrectRequest() async {
		let (client, storage, sut) = makeSUT()
        // Lanza la ejecución y espera resultado
        let executeTask = Task { try? await sut.execute() }

        // Espera a que el spy registre la petición antes de completar
        let requestRegistered = expectation(description: "Request registered")
        Task {
            while client.requests.isEmpty {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            requestRegistered.fulfill()
        }
        await fulfillment(of: [requestRegistered], timeout: 1.0)
        guard let url = client.requests.first?.url else {
            XCTFail("No request registered in HTTPClientSpy")
            return
        }
        client.complete(with: Data(), response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        // Espera a que la ejecución termine realmente
        _ = await executeTask.value

        XCTAssertEqual(storage.messages, [.loadRefreshToken, .save], "Should load and then save refresh token in storage")
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requestedHTTPMethods, ["POST"])
        XCTAssertEqual(client.requestedHeaders, [["Authorization": "Bearer any-token"]])
	}
	
	// Helpers
	private func makeSUT() -> (client: HTTPClientSpy, storage: TokenStorageSpy, sut: RefreshTokenUseCase) {
		let client = HTTPClientSpy()
		let storage = TokenStorageSpy()
		let sut = TokenRefreshService(client: client, storage: storage, parser: TokenParserSpy())
		trackForMemoryLeaks(client, file: #file, line: #line)
		trackForMemoryLeaks(storage, file: #file, line: #line)
		trackForMemoryLeaks(sut, file: #file, line: #line)
		return (client, storage, sut)
	}
}


