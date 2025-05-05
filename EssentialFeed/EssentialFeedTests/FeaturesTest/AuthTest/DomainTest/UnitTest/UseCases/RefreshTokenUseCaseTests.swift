
import XCTest
import EssentialFeed

class RefreshTokenUseCaseTests: XCTestCase {
	func test_init_noSideEffects() {
		let (client, storage, _) = makeSUT()
		XCTAssertTrue(client.messages.isEmpty)
		XCTAssertTrue(storage.messages.isEmpty)
	}
	
	func test_execute_sendsCorrectRequest() async {
		let (client, storage, sut) = makeSUT()
		_ = try? await sut.execute()
		
		XCTAssertEqual(storage.messages, [.loadRefreshToken, .save])
		XCTAssertEqual(client.messages.count, 1)
		XCTAssertEqual(client.messages.first?.httpMethod, "POST")
		XCTAssertEqual(client.messages.first?.value(forHTTPHeaderField: "Authorization"), "Bearer any-token")
	}
	
	// Helpers
	private func makeSUT() -> (client: HTTPClientSpy, storage: TokenStorageSpy, sut: RefreshTokenUseCase) {
		let client = HTTPClientSpy()
		let storage = TokenStorageSpy()
		let sut = TokenRefreshService(client: client, storage: storage, parser: TokenParserSpy())
		trackForMemoryLeaks([client, storage, sut])
		return (client, storage, sut)
	}
}

// Test Doubles
private class HTTPClientSpy: HTTPClient {
	private(set) var messages = [URLRequest]()
	func send(_ request: URLRequest) async throws -> Data {
		messages.append(request)
		return Data()
	}
}

private class TokenStorageSpy: TokenStorage {
	enum Message { case loadRefreshToken, save }
	private(set) var messages = [Message]()
	func loadRefreshToken() throws -> String {
		messages.append(.loadRefreshToken)
		return "any-token"
	}
	func save(token: Token) throws {
		messages.append(.save)
	}
}

private class TokenParserSpy: TokenParser {
	func parse(from data: Data) throws -> Token {
		Token(value: "parsed-token", expiry: Date())
	}
}
