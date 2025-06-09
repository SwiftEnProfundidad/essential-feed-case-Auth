import CryptoKit
import EssentialFeed
import XCTest

final class HMACRequestSignerTests: XCTestCase {
    func test_signRequest_addsRequiredHeaders() async throws {
        let (sut, _) = makeSUT()
        let request = URLRequest(url: anyURL())
        let nonce = "test-nonce"
        let timestamp: Int64 = 1_234_567_890

        let signedRequest = try await sut.signRequest(request, with: nonce, timestamp: timestamp)

        XCTAssertEqual(signedRequest.value(forHTTPHeaderField: "X-Nonce"), nonce, "Should add nonce header")
        XCTAssertEqual(signedRequest.value(forHTTPHeaderField: "X-Timestamp"), String(timestamp), "Should add timestamp header")
        XCTAssertNotNil(signedRequest.value(forHTTPHeaderField: "X-Signature"), "Should add signature header")
    }

    func test_signRequest_generatesConsistentSignature() async throws {
        let secretKey = Data("test-secret-key".utf8)
        let (sut, _) = makeSUT(secretKey: secretKey)
        let request = URLRequest(url: anyURL())
        let nonce = "test-nonce"
        let timestamp: Int64 = 1_234_567_890

        let signedRequest1 = try await sut.signRequest(request, with: nonce, timestamp: timestamp)
        let signedRequest2 = try await sut.signRequest(request, with: nonce, timestamp: timestamp)

        XCTAssertEqual(
            signedRequest1.value(forHTTPHeaderField: "X-Signature"),
            signedRequest2.value(forHTTPHeaderField: "X-Signature"),
            "Same inputs should produce same signature"
        )
    }

    func test_signRequest_generatesDifferentSignatureForDifferentInputs() async throws {
        let (sut, _) = makeSUT()
        let request = URLRequest(url: anyURL())

        let signedRequest1 = try await sut.signRequest(request, with: "nonce1", timestamp: 1_234_567_890)
        let signedRequest2 = try await sut.signRequest(request, with: "nonce2", timestamp: 1_234_567_890)

        XCTAssertNotEqual(
            signedRequest1.value(forHTTPHeaderField: "X-Signature"),
            signedRequest2.value(forHTTPHeaderField: "X-Signature"),
            "Different nonces should produce different signatures"
        )
    }

    func test_signRequest_throwsErrorForInvalidRequest() async {
        let (sut, _) = makeSUT()
        var invalidRequest = URLRequest(url: anyURL())
        invalidRequest.url = nil

        do {
            _ = try await sut.signRequest(invalidRequest, with: "nonce", timestamp: 123)
            XCTFail("Should throw error for invalid request")
        } catch let error as HMACRequestSigner.SigningError {
            XCTAssertEqual(error, .invalidRequest, "Should throw invalid request error")
        } catch {
            XCTFail("Should throw SigningError, got \(error)")
        }
    }

    func test_signRequest_includesHTTPBodyInSignature() async throws {
        let (sut, _) = makeSUT()
        let bodyData = Data("test-body".utf8)
        var requestWithBody = URLRequest(url: anyURL())
        requestWithBody.httpBody = bodyData
        let requestWithoutBody = URLRequest(url: anyURL())

        let signedWithBody = try await sut.signRequest(requestWithBody, with: "nonce", timestamp: 123)
        let signedWithoutBody = try await sut.signRequest(requestWithoutBody, with: "nonce", timestamp: 123)

        XCTAssertNotEqual(
            signedWithBody.value(forHTTPHeaderField: "X-Signature"),
            signedWithoutBody.value(forHTTPHeaderField: "X-Signature"),
            "Requests with different bodies should have different signatures"
        )
    }

    // MARK: - Helpers

    private func makeSUT(
        secretKey: Data = Data("default-test-key".utf8),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: HMACRequestSigner, secretKey: Data) {
        let sut = HMACRequestSigner(secretKey: secretKey)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, secretKey)
    }

    private func anyURL() -> URL {
        URL(string: "https://api.example.com/register")!
    }
}
