import XCTest
@testable import EssentialFeed // Asegúrate que esta importación esté presente para acceder a TokenRefreshService si es internal

final class RefreshTokenUseCaseTests: XCTestCase {
  
  func test_init_doesNotSendRequest() {
    let (_, client, storage, _) = makeSUT()
    
    XCTAssertTrue(client.requests.isEmpty)
    XCTAssertTrue(storage.messages.isEmpty)
  }
  
  func test_execute_sendsCorrectRequest() async throws {
    let (sut, client, storage, parserSpy) = makeSUT() // parserSpy se devuelve desde makeSUT
    let refreshURLFromSUT = URL(string: "https://any-refresh-url.com")!
    
    let executeTask = Task { try await sut.execute() }
    
    let requestRegistered = expectation(description: "Request registered")
    Task {
      while client.requests.isEmpty {
        try? await Task.sleep(nanoseconds: 10_000_000)
      }
      requestRegistered.fulfill()
    }
    
    await fulfillment(of: [requestRegistered], timeout: 1.0)
    
    guard let firstRequest = client.requests.first else {
      XCTFail("No request registered in HTTPClientSpy")
      return
    }
    XCTAssertEqual(firstRequest.url, refreshURLFromSUT)
    
    let responseData = Data()
    let response200 = HTTPURLResponse(url: firstRequest.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    client.complete(with: responseData, response: response200)
    
    _ = await executeTask.value // Asegúrate que esta línea esté correcta
    
    // Esto asegura que comparamos con el token exacto que se procesó.
    let expectedTokenFromParser = try parserSpy.parse(from: responseData)
    
    XCTAssertEqual(storage.messages, [.loadRefreshToken, .save(expectedTokenFromParser)], "Should load and then save refresh token in storage")
    XCTAssertEqual(client.requests.count, 1)
    XCTAssertEqual(client.requestedHTTPMethods, ["POST"])
    
    // XCTAssertEqual(client.requestedHeaders, [["Authorization": "Bearer any-token"]])
  }
  
  // Helpers
  private func makeSUT(
    file: StaticString = #file,
    line: UInt = #line
  ) -> (sut: RefreshTokenUseCase, client: HTTPClientSpy, storage: TokenStorageSpy, parser: TokenParserSpy) {
    let client = HTTPClientSpy()
    let storage = TokenStorageSpy()
    let parser = TokenParserSpy()
    let refreshURL = URL(string: "https://any-refresh-url.com")!
    
    let sut = TokenRefreshService(
      httpClient: client,      // Etiqueta correcta
      tokenStorage: storage,   // Etiqueta correcta
      tokenParser: parser,     // Etiqueta correcta
      refreshURL: refreshURL   // Argumento añadido y etiqueta correcta
    )
    trackForMemoryLeaks(client, file: file, line: line)
    trackForMemoryLeaks(storage, file: file, line: line)
    trackForMemoryLeaks(parser, file: file, line: line)
    trackForMemoryLeaks(sut, file: file, line: line)
    return (sut, client, storage, parser)
  }
}
