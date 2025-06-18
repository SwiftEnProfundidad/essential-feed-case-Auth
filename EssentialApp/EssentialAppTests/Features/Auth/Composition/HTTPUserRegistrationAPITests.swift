import EssentialApp
import EssentialFeed
import XCTest

final class HTTPUserRegistrationAPITests: XCTestCase {
    func test_register_returnsSuccessWithFakeData() async {
        let sut = makeSUT()
        let userData = UserRegistrationData(name: "John", email: "john@test.com", password: "password123")

        let result = await sut.register(with: userData)

        switch result {
        case let .success(response):
            XCTAssertEqual(response.userID, "test123", "Should return fake user ID")
            XCTAssertEqual(response.token, "fake-token", "Should return fake access token")
            XCTAssertEqual(response.refreshToken, "fake-refresh", "Should return fake refresh token")
        case .failure:
            XCTFail("Expected success but got failure")
        }
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> HTTPUserRegistrationAPI {
        let httpClient = HTTPClientStub { _ in
            let data = Data()
            let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return .success((data, response))
        }
        let sut = HTTPUserRegistrationAPI(client: httpClient)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(httpClient, file: file, line: line)
        return sut
    }
}
