import EssentialFeed
import XCTest

final class DefaultNonceGeneratorTests: XCTestCase {
    func test_generateNonce_generatesUniqueValues() {
        let sut = makeSUT()

        let nonce1 = sut.generateNonce()
        let nonce2 = sut.generateNonce()

        XCTAssertNotEqual(nonce1, nonce2, "Each nonce should be unique")
    }

    func test_generateNonce_returnsBase64URLSafeString() {
        let sut = makeSUT()

        let nonce = sut.generateNonce()

        XCTAssertFalse(nonce.contains("+"), "Nonce should not contain '+' character")
        XCTAssertFalse(nonce.contains("/"), "Nonce should not contain '/' character")
        XCTAssertFalse(nonce.contains("="), "Nonce should not contain '=' character")
        XCTAssertFalse(nonce.isEmpty, "Nonce should not be empty")
    }

    func test_generateNonce_hasConsistentLength() {
        let sut = makeSUT()

        let nonces = (0 ..< 10).map { _ in sut.generateNonce() }
        let lengths = Set(nonces.map(\.count))

        XCTAssertEqual(lengths.count, 1, "All nonces should have the same length")
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> DefaultNonceGenerator {
        let sut = DefaultNonceGenerator()
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
}
