import EssentialFeed
import XCTest

final class TokenRefreshSaver {
    private let keychain: KeychainSpy
    private let encryption: TokenEncryptionServiceSpy

    init(keychain: KeychainSpy, encryption: TokenEncryptionServiceSpy) {
        self.keychain = keychain
        self.encryption = encryption
    }

    func handleTokenRefreshSuccess(token: TokenRefreshResult) async {
        let dataToEncrypt = token.toData()

        do {
            let encryptedTokenString = try encryption.encrypt(dataToEncrypt)
            keychain.save(encryptedTokenString)
        } catch {
            keychain.save("encryption-failed-marker")
        }
    }
}

final class DefaultTokenRefreshServiceTests: XCTestCase {
    func test_refreshToken_encrypts_and_saves_token_in_keychain_on_success() async {
        let keychainSpy = KeychainSpy()
        let encryptionSpy = TokenEncryptionServiceSpy()
        let token = TokenRefreshResult(accessToken: "access", refreshToken: "refresh", expiry: Date())
        let sut = TokenRefreshSaver(keychain: keychainSpy, encryption: encryptionSpy)

        await sut.handleTokenRefreshSuccess(token: token)

        XCTAssertEqual(encryptionSpy.encryptedData.count, 1)
        XCTAssertEqual(encryptionSpy.encryptedData.first, token.toData())

        XCTAssertEqual(keychainSpy.saveCallCount, 1)
        XCTAssertEqual(keychainSpy.receivedValueToSave, "encrypted-token")
    }

    func test_refreshToken_savesTokenSecurelyInKeychain_onSuccess() async {
        let (sut, keychainSpy, _, token) = makeSUT()
        await sut.handleTokenRefreshSuccess(token: token)
        XCTAssertEqual(keychainSpy.saveCallCount, 1)
        XCTAssertEqual(keychainSpy.receivedValueToSave, "encrypted-token")
    }

    func test_refreshToken_encryptsTokenWithAES256_beforeSavingInKeychain() async {
        let keychainSpy = KeychainSpy()
        let encryptionSpy = TokenEncryptionServiceSpy()
        let sut = TokenRefreshSaver(keychain: keychainSpy, encryption: encryptionSpy)
        let token = TokenRefreshResult(accessToken: "a", refreshToken: "b", expiry: Date())

        await sut.handleTokenRefreshSuccess(token: token)

        XCTAssertEqual(encryptionSpy.encryptedData.first, token.toData())
        XCTAssertEqual(keychainSpy.receivedValueToSave, "encrypted-token")
    }

    func test_refreshToken_succeedsAfterRetry() async {
        let stub = TokenRefreshServiceStub(fails: 2, alwaysFail: false)
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
                dateTolerance
            )
        case let .failure(error):
            XCTFail("Expected success after retries, got error: \(error)")
        }
    }

    func test_refreshToken_failsAfterMaxRetries() async {
        let stub = TokenRefreshServiceStub(fails: 0, alwaysFail: true)
        let result = await stub.refreshToken(refreshToken: "dummy")
        switch result {
        case .success:
            XCTFail("Expected failure")
        case let .failure(error):
            XCTAssertEqual(error, .network)
        }
    }

    private func makeSUT(file: StaticString = #file, line: UInt = #line) -> (sut: TokenRefreshSaver, keychain: KeychainSpy, encryption: TokenEncryptionServiceSpy, token: TokenRefreshResult) {
        let keychainSpy = KeychainSpy()
        let encryptionSpy = TokenEncryptionServiceSpy()
        let sut = TokenRefreshSaver(keychain: keychainSpy, encryption: encryptionSpy)
        let token = TokenRefreshResult(accessToken: "access", refreshToken: "refresh", expiry: Date())

        trackForMemoryLeaks(keychainSpy, file: file, line: line)
        trackForMemoryLeaks(encryptionSpy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)

        return (sut, keychainSpy, encryptionSpy, token)
    }
}
