import EssentialFeed
import XCTest

final class HTTPUserRegistrationAPITests: XCTestCase {
    func test_init_doesNotTriggerSideEffects() async {
        let (_, client) = makeSUT()

        let requests = await client.requests
        XCTAssertEqual(requests.count, 0, "Should not trigger HTTP requests on init")
    }

    func test_register_returnsSuccessfulResponseForNow() async {
        let (sut, _) = makeSUT()
        let registrationData = UserRegistrationData(name: "John", email: "john@example.com", password: "password")

        let result = await sut.register(with: registrationData)

        if case let .success(response) = result {
            XCTAssertEqual(response.userID, "test123", "Should return test user ID")
            XCTAssertEqual(response.token, "fake-token", "Should return fake token")
            XCTAssertEqual(response.refreshToken, "fake-refresh", "Should return fake refresh token")
        } else {
            XCTFail("Expected success result, got \(result)")
        }
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: HTTPUserRegistrationAPI, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = HTTPUserRegistrationAPI(client: client)

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(client, file: file, line: line)

        return (sut, client)
    }
}
