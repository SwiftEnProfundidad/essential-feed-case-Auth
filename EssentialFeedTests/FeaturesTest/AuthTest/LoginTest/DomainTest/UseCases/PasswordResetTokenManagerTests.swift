import EssentialFeed
import XCTest

final class PasswordResetTokenManagerTests: XCTestCase {
    func test_generateResetToken_createsValidTokenWithCorrectExpiration() throws {
        let (sut, _, _, _, _, tokenGenerator) = makeSUT(expirationMinutes: 30)
        tokenGenerator.stubbedToken = "test-token-123"

        let token = try sut.generateResetToken(for: "test@example.com")

        XCTAssertEqual(token.token, "test-token-123", "Should use generated token")
        XCTAssertEqual(token.email, "test@example.com", "Should set correct email")
        XCTAssertFalse(token.isUsed, "Should be unused initially")
        XCTAssertFalse(token.isExpired, "Should not be expired initially")
        XCTAssertTrue(token.expirationDate > Date(), "Should have future expiration")
    }

    func test_generateResetToken_cleansUpExistingTokensForEmail() throws {
        let (sut, _, _, _, tokenCleaner, _) = makeSUT()

        _ = try sut.generateResetToken(for: "test@example.com")

        XCTAssertEqual(tokenCleaner.deleteTokensForEmailCallCount, 1, "Should clean existing tokens for email")
        XCTAssertEqual(tokenCleaner.deleteTokensForEmailArgs, ["test@example.com"], "Should clean tokens for correct email")
    }

    func test_generateResetToken_cleansUpExpiredTokens() throws {
        let (sut, _, _, _, tokenCleaner, _) = makeSUT()

        _ = try sut.generateResetToken(for: "test@example.com")

        XCTAssertEqual(tokenCleaner.deleteExpiredTokensCallCount, 1, "Should clean expired tokens")
    }

    func test_generateResetToken_savesTokenToStore() throws {
        let (sut, _, tokenWriter, _, _, tokenGenerator) = makeSUT()
        tokenGenerator.stubbedToken = "test-token-123"

        _ = try sut.generateResetToken(for: "test@example.com")

        XCTAssertEqual(tokenWriter.saveTokenCallCount, 1, "Should save token to store")
        XCTAssertEqual(tokenWriter.savedTokens.first?.token, "test-token-123", "Should save correct token")
    }

    func test_validateToken_returnsSuccessForValidToken() {
        let (sut, tokenReader, _, _, _, _) = makeSUT()
        let validToken = PasswordResetToken(token: "valid-token", email: "test@example.com", expirationDate: Date().addingTimeInterval(900))
        tokenReader.stubbedToken = validToken

        let result = sut.validateToken("valid-token")

        switch result {
        case let .success(token):
            XCTAssertEqual(token.token, "valid-token", "Should return correct token")
        case .failure:
            XCTFail("Expected success for valid token")
        }
    }

    func test_validateToken_returnsTokenNotFoundForNonexistentToken() {
        let (sut, tokenReader, _, _, _, _) = makeSUT()
        tokenReader.stubbedToken = nil

        let result = sut.validateToken("nonexistent-token")

        XCTAssertEqual(result, .failure(.tokenNotFound), "Should return token not found error")
    }

    func test_validateToken_returnsTokenExpiredForExpiredToken() {
        let (sut, tokenReader, _, _, _, _) = makeSUT()
        let expiredToken = PasswordResetToken(token: "expired-token", email: "test@example.com", expirationDate: Date().addingTimeInterval(-1))
        tokenReader.stubbedToken = expiredToken

        let result = sut.validateToken("expired-token")

        XCTAssertEqual(result, .failure(.tokenExpired), "Should return token expired error")
    }

    func test_validateToken_returnsTokenAlreadyUsedForUsedToken() {
        let (sut, tokenReader, _, _, _, _) = makeSUT()
        let usedToken = PasswordResetToken(token: "used-token", email: "test@example.com", expirationDate: Date().addingTimeInterval(900), isUsed: true)
        tokenReader.stubbedToken = usedToken

        let result = sut.validateToken("used-token")

        XCTAssertEqual(result, .failure(.tokenAlreadyUsed), "Should return token already used error")
    }

    func test_useToken_marksValidTokenAsUsed() throws {
        let (sut, tokenReader, _, tokenUpdater, _, _) = makeSUT()
        let validToken = PasswordResetToken(token: "valid-token", email: "test@example.com", expirationDate: Date().addingTimeInterval(900))
        tokenReader.stubbedToken = validToken

        try sut.useToken("valid-token")

        XCTAssertEqual(tokenUpdater.markTokenAsUsedCallCount, 1, "Should mark token as used")
        XCTAssertEqual(tokenUpdater.markTokenAsUsedArgs, ["valid-token"], "Should mark correct token as used")
    }

    func test_useToken_throwsErrorForInvalidToken() {
        let (sut, tokenReader, _, _, _, _) = makeSUT()
        tokenReader.stubbedToken = nil

        XCTAssertThrowsError(try sut.useToken("invalid-token")) { error in
            XCTAssertEqual(error as? PasswordResetTokenError, .tokenNotFound, "Should throw token not found error")
        }
    }

    func test_deleteExpiredTokens_delegatesToCleaner() throws {
        let (sut, _, _, _, tokenCleaner, _) = makeSUT()

        try sut.deleteExpiredTokens()

        XCTAssertEqual(tokenCleaner.deleteExpiredTokensCallCount, 1, "Should delegate cleanup to cleaner")
    }

    // MARK: - Helpers

    private func makeSUT(expirationMinutes: Int = 15, file: StaticString = #filePath, line: UInt = #line) -> (sut: DefaultPasswordResetTokenManager, tokenReader: PasswordResetTokenReaderSpy, tokenWriter: PasswordResetTokenWriterSpy, tokenUpdater: PasswordResetTokenUpdaterSpy, tokenCleaner: PasswordResetTokenCleanerSpy, tokenGenerator: PasswordResetTokenGeneratorSpy) {
        let tokenReader = PasswordResetTokenReaderSpy()
        let tokenWriter = PasswordResetTokenWriterSpy()
        let tokenUpdater = PasswordResetTokenUpdaterSpy()
        let tokenCleaner = PasswordResetTokenCleanerSpy()
        let tokenGenerator = PasswordResetTokenGeneratorSpy()
        let sut = DefaultPasswordResetTokenManager(tokenReader: tokenReader, tokenWriter: tokenWriter, tokenUpdater: tokenUpdater, tokenCleaner: tokenCleaner, tokenGenerator: tokenGenerator, expirationMinutes: expirationMinutes)

        trackForMemoryLeaks(tokenReader, file: file, line: line)
        trackForMemoryLeaks(tokenWriter, file: file, line: line)
        trackForMemoryLeaks(tokenUpdater, file: file, line: line)
        trackForMemoryLeaks(tokenCleaner, file: file, line: line)
        trackForMemoryLeaks(tokenGenerator, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)

        return (sut, tokenReader, tokenWriter, tokenUpdater, tokenCleaner, tokenGenerator)
    }
}

// MARK: - Test Doubles

private final class PasswordResetTokenReaderSpy: PasswordResetTokenReader {
    var stubbedToken: PasswordResetToken?
    var getTokenCallCount = 0
    var getTokenArgs: [String] = []

    func getToken(_ token: String) -> PasswordResetToken? {
        getTokenCallCount += 1
        getTokenArgs.append(token)
        return stubbedToken
    }

    func getTokens(for _: String) -> [PasswordResetToken] {
        []
    }
}

private final class PasswordResetTokenWriterSpy: PasswordResetTokenWriter {
    var saveTokenCallCount = 0
    var savedTokens: [PasswordResetToken] = []

    func saveToken(_ token: PasswordResetToken) throws {
        saveTokenCallCount += 1
        savedTokens.append(token)
    }
}

private final class PasswordResetTokenUpdaterSpy: PasswordResetTokenUpdater {
    var markTokenAsUsedCallCount = 0
    var markTokenAsUsedArgs: [String] = []

    func markTokenAsUsed(_ token: String) throws {
        markTokenAsUsedCallCount += 1
        markTokenAsUsedArgs.append(token)
    }
}

private final class PasswordResetTokenCleanerSpy: PasswordResetTokenCleaner {
    var deleteExpiredTokensCallCount = 0
    var deleteTokensForEmailCallCount = 0
    var deleteTokensForEmailArgs: [String] = []

    func deleteExpiredTokens() throws {
        deleteExpiredTokensCallCount += 1
    }

    func deleteTokens(for email: String) throws {
        deleteTokensForEmailCallCount += 1
        deleteTokensForEmailArgs.append(email)
    }
}

private final class PasswordResetTokenGeneratorSpy: PasswordResetTokenGenerator {
    var stubbedToken = "generated-token"
    var generateTokenCallCount = 0

    func generateToken() -> String {
        generateTokenCallCount += 1
        return stubbedToken
    }
}
