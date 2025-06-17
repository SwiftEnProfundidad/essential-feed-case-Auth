import EssentialFeed
import XCTest

final class PasswordResetTokenIntegrationTests: XCTestCase {
    func test_endToEndPasswordResetFlow_generatesValidatesAndUsesToken() throws {
        let (sut, _) = makeSUT()

        let resetToken = try sut.generateResetToken(for: "test@example.com")

        XCTAssertFalse(resetToken.token.isEmpty, "Should generate non-empty token")
        XCTAssertEqual(resetToken.email, "test@example.com", "Should set correct email")
        XCTAssertFalse(resetToken.isUsed, "Should be unused initially")
        XCTAssertFalse(resetToken.isExpired, "Should not be expired initially")

        let validationResult = sut.validateToken(resetToken.token)
        switch validationResult {
        case let .success(validatedToken):
            XCTAssertEqual(validatedToken.token, resetToken.token, "Should validate correct token")
        case .failure:
            XCTFail("Should validate generated token successfully")
        }

        try sut.useToken(resetToken.token)

        let secondValidationResult = sut.validateToken(resetToken.token)
        switch secondValidationResult {
        case let .failure(error):
            XCTAssertEqual(error, .tokenAlreadyUsed, "Should reject used token")
        case .success:
            XCTFail("Should reject used token")
        }
    }

    func test_tokenExpiration_rejectsExpiredTokens() throws {
        let (sut, _) = makeSUT(expirationMinutes: 0)

        let resetToken = try sut.generateResetToken(for: "test@example.com")

        Thread.sleep(forTimeInterval: 0.1)

        let validationResult = sut.validateToken(resetToken.token)
        switch validationResult {
        case let .failure(error):
            XCTAssertEqual(error, .tokenExpired, "Should reject expired token")
        case .success:
            XCTFail("Should reject expired token")
        }
    }

    func test_oneTimeUse_rejectsSecondUseAttempt() throws {
        let (sut, _) = makeSUT()

        let resetToken = try sut.generateResetToken(for: "test@example.com")

        try sut.useToken(resetToken.token)

        XCTAssertThrowsError(try sut.useToken(resetToken.token)) { error in
            XCTAssertEqual(error as? PasswordResetTokenError, .tokenAlreadyUsed, "Should reject second use of same token")
        }
    }

    func test_generateNewToken_invalidatesPreviousTokensForSameEmail() throws {
        let (sut, _) = makeSUT()

        let firstToken = try sut.generateResetToken(for: "test@example.com")
        let secondToken = try sut.generateResetToken(for: "test@example.com")

        XCTAssertNotEqual(firstToken.token, secondToken.token, "Should generate different tokens")

        let firstTokenValidation = sut.validateToken(firstToken.token)
        switch firstTokenValidation {
        case let .failure(error):
            XCTAssertEqual(error, .tokenNotFound, "Should invalidate previous token")
        case .success:
            XCTFail("Should invalidate previous token")
        }

        let secondTokenValidation = sut.validateToken(secondToken.token)
        switch secondTokenValidation {
        case .success:
            break
        case .failure:
            XCTFail("Should validate new token successfully")
        }
    }

    // MARK: - Helpers

    private func makeSUT(expirationMinutes: Int = 15, file: StaticString = #filePath, line: UInt = #line) -> (sut: DefaultPasswordResetTokenManager, store: PasswordResetTokenMemoryStore) {
        let tokenStore = PasswordResetTokenMemoryStore()
        let tokenGenerator = CryptoKitPasswordResetTokenGenerator()
        let sut = DefaultPasswordResetTokenManager(tokenReader: tokenStore, tokenWriter: tokenStore, tokenUpdater: tokenStore, tokenCleaner: tokenStore, tokenGenerator: tokenGenerator, expirationMinutes: expirationMinutes)

        trackForMemoryLeaks(tokenStore, file: file, line: line)
        trackForMemoryLeaks(tokenGenerator, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)

        return (sut, tokenStore)
    }
}
