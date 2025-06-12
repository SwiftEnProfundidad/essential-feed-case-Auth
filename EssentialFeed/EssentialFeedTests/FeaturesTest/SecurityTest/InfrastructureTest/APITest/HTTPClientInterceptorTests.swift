import EssentialFeed
import XCTest

final class HTTPClientInterceptorTests: XCTestCase {
    func test_interceptor_protocol_conforms_to_expected_signature() {
        let sut = DummyInterceptor()

        XCTAssertNotNil(sut, "HTTPClientInterceptor should be implementable")
    }
}

private final class DummyInterceptor: HTTPClientInterceptor {
    func intercept(_ request: URLRequest, next: HTTPClient) async throws -> (Data, HTTPURLResponse) {
        try await next.send(request)
    }
}
