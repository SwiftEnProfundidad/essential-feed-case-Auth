import EssentialFeed
import XCTest

final class DefaultReplayAttackProtectorTests: XCTestCase {
    func test_protectRequest_addsNonceTimestampAndSignature() async throws {
        let (sut, nonceGeneratorSpy, timestampProviderSpy, requestSignerSpy) = makeSUT()
        let request = URLRequest(url: anyURL())
        nonceGeneratorSpy.stubbedNonce = "generated-nonce"
        timestampProviderSpy.stubbedTimestamp = 9_876_543_210
        requestSignerSpy.stubbedSignedRequest = URLRequest(url: anyURL())

        _ = try await sut.protectRequest(request)

        XCTAssertEqual(nonceGeneratorSpy.generateNonceCallCount, 1, "Should generate nonce")
        XCTAssertEqual(timestampProviderSpy.currentTimestampCallCount, 1, "Should get current timestamp")
        XCTAssertEqual(requestSignerSpy.signRequestCallCount, 1, "Should sign request")
        XCTAssertEqual(requestSignerSpy.receivedRequest, request, "Should sign the original request")
        XCTAssertEqual(requestSignerSpy.receivedNonce, "generated-nonce", "Should use generated nonce")
        XCTAssertEqual(requestSignerSpy.receivedTimestamp, 9_876_543_210, "Should use current timestamp")
    }

    func test_protectRequest_returnsSignedRequest() async throws {
        let (sut, nonceGeneratorSpy, timestampProviderSpy, requestSignerSpy) = makeSUT()
        let originalRequest = URLRequest(url: anyURL())
        let expectedSignedRequest = URLRequest(url: URL(string: "https://signed.example.com")!)
        requestSignerSpy.stubbedSignedRequest = expectedSignedRequest

        let result = try await sut.protectRequest(originalRequest)

        XCTAssertEqual(result, expectedSignedRequest, "Should return the signed request from RequestSigner")
    }

    func test_protectRequest_propagatesSigningError() async {
        let (sut, _, _, requestSignerSpy) = makeSUT()
        let request = URLRequest(url: anyURL())
        requestSignerSpy.stubbedError = TestError.signingFailed

        do {
            _ = try await sut.protectRequest(request)
            XCTFail("Should propagate signing error")
        } catch {
            XCTAssertEqual(error as? TestError, .signingFailed, "Should propagate the exact error from RequestSigner")
        }
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: DefaultReplayAttackProtector,
        nonceGenerator: NonceGeneratorSpy,
        timestampProvider: TimestampProviderSpy,
        requestSigner: RequestSignerSpy
    ) {
        let nonceGeneratorSpy = NonceGeneratorSpy()
        let timestampProviderSpy = TimestampProviderSpy()
        let requestSignerSpy = RequestSignerSpy()

        let sut = DefaultReplayAttackProtector(
            nonceGenerator: nonceGeneratorSpy,
            timestampProvider: timestampProviderSpy,
            requestSigner: requestSignerSpy
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(nonceGeneratorSpy, file: file, line: line)
        trackForMemoryLeaks(timestampProviderSpy, file: file, line: line)
        trackForMemoryLeaks(requestSignerSpy, file: file, line: line)

        return (sut, nonceGeneratorSpy, timestampProviderSpy, requestSignerSpy)
    }

    private func anyURL() -> URL {
        URL(string: "https://api.example.com/register")!
    }

    enum TestError: Error, Equatable {
        case signingFailed
    }
}

// MARK: - Test Doubles

final class NonceGeneratorSpy: NonceGenerator {
    var stubbedNonce = "default-nonce"
    private(set) var generateNonceCallCount = 0

    func generateNonce() -> String {
        generateNonceCallCount += 1
        return stubbedNonce
    }
}

final class TimestampProviderSpy: TimestampProvider {
    var stubbedTimestamp: Int64 = 1_234_567_890
    private(set) var currentTimestampCallCount = 0

    func currentTimestamp() -> Int64 {
        currentTimestampCallCount += 1
        return stubbedTimestamp
    }
}

final class RequestSignerSpy: RequestSigner {
    var stubbedSignedRequest: URLRequest = .init(url: URL(string: "https://example.com")!)
    var stubbedError: Error?

    private(set) var signRequestCallCount = 0
    private(set) var receivedRequest: URLRequest?
    private(set) var receivedNonce: String?
    private(set) var receivedTimestamp: Int64?

    func signRequest(_ request: URLRequest, with nonce: String, timestamp: Int64) async throws -> URLRequest {
        signRequestCallCount += 1
        receivedRequest = request
        receivedNonce = nonce
        receivedTimestamp = timestamp

        if let error = stubbedError {
            throw error
        }

        return stubbedSignedRequest
    }
}
