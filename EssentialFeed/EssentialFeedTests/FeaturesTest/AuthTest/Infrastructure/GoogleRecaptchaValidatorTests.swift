import EssentialFeed
import XCTest

final class GoogleRecaptchaValidatorTests: XCTestCase {
    func test_validateCaptcha_withValidResponse_returnsValidResult() async throws {
        let (sut, httpClient) = makeSUT()
        let responseData = makeSuccessResponseData(success: true, score: 0.8)
        await httpClient.stubNextSend(result: .success((responseData, anyHTTPURLResponse())))

        let result = try await sut.validateCaptcha(response: "valid-response", clientIP: "192.168.1.1")

        XCTAssertTrue(result.isValid, "Should return valid result for successful response")
        XCTAssertEqual(result.score, 0.8, "Should return correct score")
        let requestCount = await httpClient.requests.count
        XCTAssertEqual(requestCount, 1, "Should make one HTTP request")
    }

    func test_validateCaptcha_withInvalidResponse_returnsInvalidResult() async throws {
        let (sut, httpClient) = makeSUT()
        let responseData = makeSuccessResponseData(success: false, score: nil)
        await httpClient.stubNextSend(result: .success((responseData, anyHTTPURLResponse())))

        let result = try await sut.validateCaptcha(response: "invalid-response", clientIP: nil)

        XCTAssertFalse(result.isValid, "Should return invalid result for failed response")
        XCTAssertNil(result.score, "Should not have score for failed response")
    }

    func test_validateCaptcha_withNetworkError_throwsError() async {
        let (sut, httpClient) = makeSUT()
        let error = NSError(domain: "TestError", code: 500, userInfo: nil)
        await httpClient.stubNextSend(result: .failure(error))

        do {
            _ = try await sut.validateCaptcha(response: "test-response", clientIP: nil)
            XCTFail("Should throw error for network failure")
        } catch {
            XCTAssertTrue(error is CaptchaError, "Should throw CaptchaError")
        }
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: GoogleRecaptchaValidator, httpClient: HTTPClientSpy) {
        let httpClient = HTTPClientSpy()
        let sut = GoogleRecaptchaValidator(secretKey: "test-secret", httpClient: httpClient)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(httpClient, file: file, line: line)
        return (sut, httpClient)
    }

    private func makeSuccessResponseData(success: Bool, score: Double?) -> Data {
        let response = [
            "success": success,
            "score": score,
            "challenge_ts": "2023-01-01T12:00:00Z"
        ] as [String: Any?]

        return try! JSONSerialization.data(withJSONObject: response.compactMapValues { $0 })
    }

    private func anyHTTPURLResponse(statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: anyURL(), statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    private func anyURL() -> URL {
        URL(string: "https://any-url.com")!
    }
}
