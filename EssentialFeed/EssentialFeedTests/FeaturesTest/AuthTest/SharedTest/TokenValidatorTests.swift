import EssentialFeed
import XCTest

final class TokenValidatorTests: XCTestCase {
    func test_isTokenValid_withValidUnexpiredJWT_returnsTrue() {
        let sut = makeSUT()
        let token = Self.createJWT(exp: Date().addingTimeInterval(60))
        XCTAssertTrue(sut.isTokenValid(token))
    }

    func test_isTokenValid_withExpiredJWT_returnsFalse() {
        let sut = makeSUT()
        let token = Self.createJWT(exp: Date().addingTimeInterval(-3600))
        XCTAssertFalse(sut.isTokenValid(token))
    }

    func test_expirationDate_returnsCorrectDate() {
        let sut = makeSUT()
        let exp = Date().addingTimeInterval(1234)
        let token = Self.createJWT(exp: exp)
        guard let result = sut.expirationDate(of: token) else {
            XCTFail("Missing date")
            return
        }
        XCTAssertEqual(Int(result.timeIntervalSince1970), Int(exp.timeIntervalSince1970))
    }

    func test_isTokenValid_withMalformedToken_returnsFalse() {
        let sut = makeSUT()
        XCTAssertFalse(sut.isTokenValid("abc.def"))
        XCTAssertFalse(sut.isTokenValid("not_a_jwt"))
        XCTAssertFalse(sut.isTokenValid(""))
    }

    func test_validationError_withMalformedToken_returnsMalformed() {
        let sut = makeSUT()
        XCTAssertEqual(sut.validationError(for: "not_a_jwt"), .malformed)
        XCTAssertEqual(sut.validationError(for: ""), .malformed)
    }

    func test_validationError_missingExpIsMissingExp() {
        let sut = makeSUT()
        let payload = ["sub": "123"]
        let token = Self.jwtWithPayload(payload)
        XCTAssertEqual(sut.validationError(for: token), .missingExp)
    }

    func test_validationError_withExpired_returnsExpired() {
        let sut = makeSUT()
        let exp = Date().addingTimeInterval(-10)
        let token = Self.createJWT(exp: exp)
        if case let .expired(expiry) = sut.validationError(for: token) {
            XCTAssertEqual(Int(expiry.timeIntervalSince1970), Int(exp.timeIntervalSince1970))
        } else {
            XCTFail("Expected expired error")
        }
    }

    func test_validationError_withFutureNbf_returnsNotYetValid() {
        let sut = makeSUT()
        let nbf = Date().addingTimeInterval(60)
        let exp = Date().addingTimeInterval(3600)
        let payload: [String: Any] = [
            "exp": Int(exp.timeIntervalSince1970),
            "nbf": nbf.timeIntervalSince1970
        ]
        let token = Self.jwtWithPayload(payload)
        if case let .notYetValid(date) = sut.validationError(for: token) {
            XCTAssertEqual(Int(date.timeIntervalSince1970), Int(nbf.timeIntervalSince1970))
        } else {
            XCTFail("Expected notYetValid")
        }
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> JWTTokenValidator {
        let sut = JWTTokenValidator()
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }

    private static func createJWT(exp: Date) -> String {
        let header = ["alg": "HS256", "typ": "JWT"]
        let payload = ["exp": Int(exp.timeIntervalSince1970)]
        return jwtWithPayload(payload, header: header)
    }

    private static func jwtWithPayload(_ payload: [String: Any], header: [String: Any] = ["alg": "HS256", "typ": "JWT"]) -> String {
        let headerData = try! JSONSerialization.data(withJSONObject: header, options: [])
        let payloadData = try! JSONSerialization.data(withJSONObject: payload, options: [])
        let headerString = base64UrlEncode(headerData)
        let payloadString = base64UrlEncode(payloadData)
        return [headerString, payloadString, ""].joined(separator: ".")
    }

    private static func base64UrlEncode(_ data: Data) -> String {
        var str = data.base64EncodedString()
        str = str.replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return str
    }
}
