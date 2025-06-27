import EssentialFeed
import XCTest

// Stubs/Spies needed for tests
class PasswordResetTokenStoreSpy: PasswordResetTokenStore {
    // ... implementation ...
}

class PasswordUpdaterSpy: PasswordUpdater {
    // ... implementation ...
}

class PasswordValidatorSpy: PasswordValidator {
    // ... implementation ...
}

final class PasswordResetUseCaseTests: XCTestCase {
    func test_reset_failsWithValidationError_forWeakPassword() {
        let (sut, _, passwordUpdater, validator) = makeSUT()
        let weakPassword = "weak"
        let validationError = PasswordValidationError.tooShort
        validator.stub(with: .failure(validationError))

        let result = resetPasswordSync(sut: sut, token: "any-token", newPassword: weakPassword)

        XCTAssertEqual(result, .failure(.validationFailed(validationError)))
        XCTAssertTrue(passwordUpdater.receivedUpdates.isEmpty)
    }

    func test_reset_deliversErrorOnTokenNotFound() {
        let (sut, tokenStore, _, _) = makeSUT()
        tokenStore.stub(getTokenResult: nil)

        let result = resetPasswordSync(sut: sut, token: "non-existent", newPassword: "ValidPassword1!")

        XCTAssertEqual(result, .failure(.tokenNotFound))
    }

    // This is where existing tests would go.
    // They would need to be updated to call the new makeSUT.
    // For example:

    // Existing tests will need to be updated to use the new makeSUT

    // MARK: - Helpers

    private func resetPasswordSync(sut: PasswordResetUseCase, token: String, newPassword: String) -> Result<Void, PasswordResetTokenError>? {
        var receivedResult: Result<Void, PasswordResetTokenError>?
        let expectation = self.expectation(description: "Wait for reset password completion")

        sut.resetPassword(token: token, newPassword: newPassword) { result in
            receivedResult = result
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        return receivedResult
    }

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: PasswordResetUseCase, tokenStore: PasswordResetTokenStoreSpy, passwordUpdater: PasswordUpdaterSpy, validator: PasswordValidatorSpy) {
        let tokenStore = PasswordResetTokenStoreSpy()
        let passwordUpdater = PasswordUpdaterSpy()
        let validator = PasswordValidatorSpy()
        let sut = DefaultPasswordResetUseCase(tokenStore: tokenStore, passwordUpdater: passwordUpdater, passwordValidator: validator)

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(tokenStore, file: file, line: line)
        trackForMemoryLeaks(passwordUpdater, file: file, line: line)
        trackForMemoryLeaks(validator, file: file, line: line)

        return (sut, tokenStore, passwordUpdater, validator)
    }
}

private class PasswordResetTokenStoreSpy: PasswordResetTokenStore {
    var tokens = [PasswordResetToken]()
    private var getTokenStub: PasswordResetToken?

    func getToken(_: String) -> PasswordResetToken? {
        getTokenStub
    }

    func markTokenAsUsed(_: String) throws {}

    func stub(getTokenResult: PasswordResetToken?) {
        self.getTokenStub = getTokenResult
    }
}

private class PasswordUpdaterSpy: PasswordUpdater {
    var receivedUpdates = [(email: String, password: String)]()

    func updatePassword(for email: String, newPassword: String, completion: @escaping (Result<Void, Error>) -> Void) {
        receivedUpdates.append((email, newPassword))
        completion(.success(()))
    }
}

private class PasswordValidatorSpy: PasswordValidator {
    private var stubbedResult: Result<Void, PasswordValidationError> = .success(())

    func validate(password _: String) -> Result<Void, PasswordValidationError> {
        stubbedResult
    }

    func stub(with result: Result<Void, PasswordValidationError>) {
        self.stubbedResult = result
    }
}
