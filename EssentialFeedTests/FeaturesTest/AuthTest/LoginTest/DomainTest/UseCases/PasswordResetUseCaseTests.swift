import EssentialFeed
import XCTest

final class PasswordResetUseCaseTests: XCTestCase {
    func test_resetPassword_updatesPasswordAndMarksTokenAsUsed_onValidToken() {
        let (sut, tokenStore, passwordUpdater) = makeSUT()
        let validToken = PasswordResetToken(token: "valid-token", email: "test@example.com", expirationDate: Date().addingTimeInterval(900))
        tokenStore.stubbedToken = validToken

        let result = resetPasswordSync(sut: sut, token: "valid-token", newPassword: "NewPassword123!")

        switch result {
        case .success:
            XCTAssertEqual(passwordUpdater.updatePasswordCallCount, 1, "Should update password")
            XCTAssertEqual(passwordUpdater.updatePasswordArgs.first?.email, "test@example.com", "Should update password for correct email")
            XCTAssertEqual(passwordUpdater.updatePasswordArgs.first?.newPassword, "NewPassword123!", "Should use new password")
            XCTAssertEqual(tokenStore.markTokenAsUsedCallCount, 1, "Should mark token as used")
            XCTAssertEqual(tokenStore.markTokenAsUsedArgs.first, "valid-token", "Should mark correct token as used")
        case let .failure(error):
            XCTFail("Expected success for valid token, got \(error)")
        }
    }

    func test_resetPassword_returnsTokenNotFound_forNonexistentToken() {
        let (sut, tokenStore, _) = makeSUT()
        tokenStore.stubbedToken = nil

        let result = resetPasswordSync(sut: sut, token: "nonexistent-token", newPassword: "NewPassword123!")

        switch result {
        case .success:
            XCTFail("Expected tokenNotFound error for nonexistent token")
        case let .failure(error):
            XCTAssertEqual(error, PasswordResetTokenError.tokenNotFound, "Should return token not found error")
        }
    }

    func test_resetPassword_returnsTokenExpired_forExpiredToken() {
        let (sut, tokenStore, _) = makeSUT()
        let expiredToken = PasswordResetToken(token: "expired-token", email: "test@example.com", expirationDate: Date().addingTimeInterval(-900))
        tokenStore.stubbedToken = expiredToken

        let result = resetPasswordSync(sut: sut, token: "expired-token", newPassword: "NewPassword123!")

        switch result {
        case .success:
            XCTFail("Expected tokenExpired error for expired token")
        case let .failure(error):
            XCTAssertEqual(error, PasswordResetTokenError.tokenExpired, "Should return token expired error")
        }
    }

    func test_resetPassword_returnsTokenAlreadyUsed_forUsedToken() {
        let (sut, tokenStore, _) = makeSUT()
        let usedToken = PasswordResetToken(token: "used-token", email: "test@example.com", expirationDate: Date().addingTimeInterval(900), isUsed: true)
        tokenStore.stubbedToken = usedToken

        let result = resetPasswordSync(sut: sut, token: "used-token", newPassword: "NewPassword123!")

        switch result {
        case .success:
            XCTFail("Expected tokenAlreadyUsed error for used token")
        case let .failure(error):
            XCTAssertEqual(error, PasswordResetTokenError.tokenAlreadyUsed, "Should return token already used error")
        }
    }

    func test_resetPassword_returnsStorageError_whenPasswordUpdateFails() {
        let (sut, tokenStore, passwordUpdater) = makeSUT()
        let validToken = PasswordResetToken(token: "valid-token", email: "test@example.com", expirationDate: Date().addingTimeInterval(900))
        tokenStore.stubbedToken = validToken
        passwordUpdater.stubbedResult = .failure(NSError(domain: "test", code: 1))

        let result = resetPasswordSync(sut: sut, token: "valid-token", newPassword: "NewPassword123!")

        switch result {
        case .success:
            XCTFail("Expected storageError when password update fails")
        case let .failure(error):
            XCTAssertEqual(error, PasswordResetTokenError.storageError, "Should return storage error when password update fails")
        }
    }

    func test_resetPassword_doesNotMarkTokenAsUsed_whenPasswordUpdateFails() {
        let (sut, tokenStore, passwordUpdater) = makeSUT()
        let validToken = PasswordResetToken(token: "valid-token", email: "test@example.com", expirationDate: Date().addingTimeInterval(900))
        tokenStore.stubbedToken = validToken
        passwordUpdater.stubbedResult = .failure(NSError(domain: "test", code: 1))

        _ = resetPasswordSync(sut: sut, token: "valid-token", newPassword: "NewPassword123!")

        XCTAssertEqual(tokenStore.markTokenAsUsedCallCount, 0, "Should not mark token as used when password update fails")
    }

    // MARK: - Helpers

    private func resetPasswordSync(sut: PasswordResetUseCase, token: String, newPassword: String) -> Result<Void, PasswordResetTokenError> {
        let exp = expectation(description: "Wait for password reset")
        var receivedResult: Result<Void, PasswordResetTokenError>?
        sut.resetPassword(token: token, newPassword: newPassword) { result in
            receivedResult = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        return receivedResult ?? .failure(.storageError)
    }

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: PasswordResetUseCase, tokenStore: PasswordResetTokenStoreSpy, passwordUpdater: PasswordUpdaterSpy) {
        let tokenStore = PasswordResetTokenStoreSpy()
        let passwordUpdater = PasswordUpdaterSpy()
        let sut = DefaultPasswordResetUseCase(tokenStore: tokenStore, passwordUpdater: passwordUpdater)
        trackForMemoryLeaks(tokenStore, file: file, line: line)
        trackForMemoryLeaks(passwordUpdater, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, tokenStore, passwordUpdater)
    }
}

// MARK: - Test Doubles

private final class PasswordResetTokenStoreSpy: PasswordResetTokenStore {
    var stubbedToken: PasswordResetToken?
    var markTokenAsUsedCallCount = 0
    var markTokenAsUsedArgs: [String] = []
    var shouldThrowOnMarkAsUsed = false

    func getToken(_: String) -> PasswordResetToken? {
        stubbedToken
    }

    func getTokens(for _: String) -> [PasswordResetToken] {
        stubbedToken.map { [$0] } ?? []
    }

    func saveToken(_ token: PasswordResetToken) throws {
        stubbedToken = token
    }

    func markTokenAsUsed(_ token: String) throws {
        markTokenAsUsedCallCount += 1
        markTokenAsUsedArgs.append(token)
        if shouldThrowOnMarkAsUsed {
            throw PasswordResetTokenError.storageError
        }
    }

    func deleteTokens(for _: String) throws {}
    func deleteExpiredTokens() throws {}
}

private final class PasswordUpdaterSpy: PasswordUpdater {
    var updatePasswordCallCount = 0
    var updatePasswordArgs: [(email: String, newPassword: String)] = []
    var stubbedResult: Result<Void, Error> = .success(())

    func updatePassword(for email: String, newPassword: String, completion: @escaping (Result<Void, Error>) -> Void) {
        updatePasswordCallCount += 1
        updatePasswordArgs.append((email: email, newPassword: newPassword))
        completion(stubbedResult)
    }
}
