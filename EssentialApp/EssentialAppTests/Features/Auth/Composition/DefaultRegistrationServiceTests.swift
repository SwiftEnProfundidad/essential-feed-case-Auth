import EssentialApp
import EssentialFeed
import XCTest

final class DefaultRegistrationServiceTests: XCTestCase {
    func test_register_success_savesTokenAndReturnsSuccess() async {
        let (sut, registrationAPISpy, tokenStorageSpy, _) = makeSUT()
        let expectedResponse = UserRegistrationResponse(userID: "user123", token: "access-token", refreshToken: "refresh-token")
        registrationAPISpy.result = .success(expectedResponse)

        let result = await sut.register(name: "John", email: "john@test.com", password: "password123")

        switch result {
        case let .success(tokenAndUser):
            XCTAssertEqual(tokenAndUser.token.accessToken, "access-token", "Should return correct access token")
            XCTAssertEqual(tokenAndUser.token.refreshToken, "refresh-token", "Should return correct refresh token")
            XCTAssertEqual(tokenAndUser.user.name, "John", "Should return correct user name")
            XCTAssertEqual(tokenAndUser.user.email, "john@test.com", "Should return correct user email")
            let saveCount = await tokenStorageSpy.saveCallCount
            XCTAssertEqual(saveCount, 1, "Should save token once")
        case .failure:
            XCTFail("Expected success but got failure")
        }
    }

    func test_register_apiFailure_returnsFailure() async {
        let (sut, registrationAPISpy, _, _) = makeSUT()
        let expectedError = UserRegistrationError.emailAlreadyInUse
        registrationAPISpy.result = .failure(expectedError)

        let result = await sut.register(name: "John", email: "john@test.com", password: "password123")

        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case let .failure(error):
            XCTAssertEqual(error as? UserRegistrationError, expectedError, "Should return API error")
        }
    }

    func test_register_tokenStorageFailure_returnsFailure() async {
        let (sut, registrationAPISpy, tokenStorageSpy, _) = makeSUT()
        let expectedResponse = UserRegistrationResponse(userID: "user123", token: "access-token", refreshToken: "refresh-token")
        registrationAPISpy.result = .success(expectedResponse)
        await tokenStorageSpy.setShouldThrowOnSave(true)

        let result = await sut.register(name: "John", email: "john@test.com", password: "password123")

        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure:
            let saveCount = await tokenStorageSpy.saveCallCount
            XCTAssertEqual(saveCount, 1, "Should attempt to save token")
        }
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: DefaultRegistrationService, registrationAPI: RegistrationAPISpy, tokenStorage: TokenStorageTestSpy, offlineStore: OfflineRegistrationTestSpy) {
        let registrationAPISpy = RegistrationAPISpy()
        let tokenStorageSpy = TokenStorageTestSpy()
        let offlineStoreSpy = OfflineRegistrationTestSpy()
        let sut = DefaultRegistrationService(
            registrationAPI: registrationAPISpy,
            tokenStorage: tokenStorageSpy,
            offlineStore: offlineStoreSpy
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(registrationAPISpy, file: file, line: line)
        trackForMemoryLeaks(tokenStorageSpy, file: file, line: line)
        trackForMemoryLeaks(offlineStoreSpy, file: file, line: line)

        return (sut, registrationAPISpy, tokenStorageSpy, offlineStoreSpy)
    }
}

private final class RegistrationAPISpy: UserRegistrationAPI {
    var result: Result<UserRegistrationResponse, UserRegistrationError> = .failure(.invalidData)
    private(set) var callCount = 0

    func register(with _: UserRegistrationData) async -> Result<UserRegistrationResponse, UserRegistrationError> {
        callCount += 1
        return result
    }
}

private actor TokenStorageTestSpy: TokenStorage {
    private(set) var saveCallCount = 0
    private var shouldThrowOnSave = false
    private let throwError = TokenStorageError.encodingFailed(nil)

    func setShouldThrowOnSave(_ value: Bool) {
        shouldThrowOnSave = value
    }

    func save(tokenBundle _: Token) async throws {
        saveCallCount += 1
        if shouldThrowOnSave {
            throw throwError
        }
    }

    func loadTokenBundle() async throws -> Token? { nil }
    func deleteTokenBundle() async throws {}
}

private final class OfflineRegistrationTestSpy: OfflineRegistrationStore {
    private(set) var saveCallCount = 0

    func save(_: UserRegistrationData) async throws {
        saveCallCount += 1
    }
}
