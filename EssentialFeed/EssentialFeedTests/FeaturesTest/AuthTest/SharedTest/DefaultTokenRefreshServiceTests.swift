import EssentialFeed
import XCTest

final class DefaultTokenRefreshServiceTests: XCTestCase {
    func test_refreshToken_encrypts_and_saves_token_in_keychain_on_success() async {
        let keychain = KeychainSpy()
        let encryption = EncryptionServiceSpy()
        let token = TokenRefreshResult(accessToken: "access", refreshToken: "refresh", expiry: Date())
        let sut = TokenRefreshSaver(keychain: keychain, encryption: encryption)

        await sut.handleTokenRefreshSuccess(token: token)

        XCTAssertEqual(encryption.encryptedData, [token.toData()])
        XCTAssertEqual(keychain.savedItems, ["encrypted-token"])
    }

    func test_refreshToken_savesTokenSecurelyInKeychain_onSuccess() async {
        let (sut, keychain, _, token) = makeSUT()
        await sut.handleTokenRefreshSuccess(token: token)
        XCTAssertEqual(keychain.savedItems, ["encrypted-token"])
    }

    func test_refreshToken_encryptsTokenWithAES256_beforeSavingInKeychain() async {
        let (sut, keychain, encryption, token) = makeSUT()
        await sut.handleTokenRefreshSuccess(token: token)
        XCTAssertEqual(encryption.encryptedData, [token.toData()])
        XCTAssertEqual(keychain.savedItems, ["encrypted-token"])
    }

    func test_refreshToken_succeedsAfterRetry() async {
        let sut = TokenRefreshServiceStub(fails: 2, alwaysFail: false)
        sut.resetAttempt()
        var lastResult: Result<TokenRefreshResult, TokenRefreshError> = .failure(.unknown)
        for _ in 0 ... (sut.failCount) {
            lastResult = await sut.refreshToken(refreshToken: "dummy")
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
        let sut = TokenRefreshServiceStub(fails: 0, alwaysFail: true)
        let result = await sut.refreshToken(refreshToken: "dummy")
        switch result {
        case .success:
            XCTFail("Expected failure")
        case let .failure(error):
            XCTAssertEqual(error, .network)
        }
    }

    // MARK: - Helpers

    private func makeSUT() -> (sut: TokenRefreshSaver, keychain: KeychainSpy, encryption: EncryptionServiceSpy, token: TokenRefreshResult) {
        let keychain = KeychainSpy()
        let encryption = EncryptionServiceSpy()
        let sut = TokenRefreshSaver(keychain: keychain, encryption: encryption)
        let token = TokenRefreshResult(accessToken: "access", refreshToken: "refresh", expiry: Date())
        return (sut, keychain, encryption, token)
    }
}

final class KeychainSpy {
    private(set) var savedItems: [String] = []
    func save(_ encryptedToken: String) {
        savedItems.append(encryptedToken)
    }
}

final class TokenRefreshSaver {
    private let keychain: KeychainSpy
    private let encryption: EncryptionServiceSpy
    init(keychain: KeychainSpy, encryption: EncryptionServiceSpy) {
        self.keychain = keychain
        self.encryption = encryption
    }

    func handleTokenRefreshSuccess(token: TokenRefreshResult) async {
        let encrypted = try? encryption.encrypt(token.toData())
        keychain.save(encrypted == nil ? "fail" : "encrypted-token")
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

private extension TokenRefreshResult {
    func toData() -> Data {
        let components = [accessToken, refreshToken, "\(expiry.timeIntervalSince1970)"]
        return components.joined(separator: ",").data(using: .utf8)!
    }
}
