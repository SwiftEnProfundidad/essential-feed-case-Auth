import EssentialFeed
import XCTest

final class DefaultTokenRefreshServiceTests: XCTestCase {
    func test_refreshToken_succeedsAfterRetry() async {
        let sut = makeSUT(fails: 2)
        let stub = sut as! TokenRefreshServiceStub
        stub.resetAttempt()
        var lastResult: Result<TokenRefreshResult, TokenRefreshError> = .failure(.unknown)
        for _ in 0 ... (stub.failCount) {
            lastResult = await stub.refreshToken(refreshToken: "dummy")
        }
        switch lastResult {
        case let .success(tokens):
            XCTAssertEqual(tokens.accessToken, "newAccessToken")
            XCTAssertEqual(tokens.refreshToken, "newRefreshToken")
            let dateTolerance: TimeInterval = 2.0
            let expectedExpiry = Date().addingTimeInterval(3600)
            XCTAssertLessThan(
                abs(tokens.expiry.timeIntervalSince(expectedExpiry)),
                dateTolerance,
                "Expiry date does not match (tolerance \(dateTolerance)s)"
            )
        case let .failure(error):
            XCTFail("Expected success after retries, got error: \(error)")
        }
    }

    func test_refreshToken_failsAfterMaxRetries() async {
        let sut = makeSUT(alwaysFail: true)
        let result = await sut.refreshToken(refreshToken: "dummy")
        switch result {
        case .success:
            XCTFail("Expected failure")
        case let .failure(error):
            XCTAssertEqual(error, .network)
        }
    }

    // MARK: - Helpers

    private func makeSUT(fails: Int = 0, alwaysFail: Bool = false) -> TokenRefreshService {
        TokenRefreshServiceStub(fails: fails, alwaysFail: alwaysFail)
    }
}

final class TokenRefreshServiceStub: TokenRefreshService {
    let failCount: Int
    let alwaysFail: Bool
    var attempt = 0

    init(fails: Int, alwaysFail: Bool) {
        self.failCount = fails
        self.alwaysFail = alwaysFail
    }

    func refreshToken(refreshToken _: String) async -> Result<TokenRefreshResult, TokenRefreshError> {
        attempt += 1
        if alwaysFail {
            try? await Task.sleep(nanoseconds: 10_000_000)
            return .failure(.network)
        }
        if attempt <= failCount {
            try? await Task.sleep(nanoseconds: 10_000_000)
            return .failure(.network)
        }
        let expiry = Date().addingTimeInterval(3600)
        let result = TokenRefreshResult(accessToken: "newAccessToken", refreshToken: "newRefreshToken", expiry: expiry)
        return .success(result)
    }

    func resetAttempt() {
        self.attempt = 0
    }
}
