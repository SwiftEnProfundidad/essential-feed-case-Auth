import EssentialFeed
import XCTest

final class DefaultRegistrationServiceTests: XCTestCase {
    func test_init_doesNotTriggerSideEffects() async {
        let (_, api, tokenStorage, offlineStore) = makeSUT()

        XCTAssertEqual(api.registrationRequests.count, 0, "Should not trigger registration on init")
        let tokenStorageMessages = await tokenStorage.messages
        XCTAssertEqual(tokenStorageMessages.count, 0, "Should not trigger token save on init")
        XCTAssertEqual(offlineStore.messages.count, 0, "Should not trigger offline save on init")
    }

    func test_register_callsRegistrationAPIWithCorrectData() async {
        let (sut, api, _, _) = makeSUT()
        let name = "John Doe"
        let email = "john@example.com"
        let password = "password123"

        _ = await sut.register(name: name, email: email, password: password)

        XCTAssertEqual(api.registrationRequests.count, 1, "Should call registration API once")
        XCTAssertEqual(api.registrationRequests.first?.name, name, "Should pass correct name")
        XCTAssertEqual(api.registrationRequests.first?.email, email, "Should pass correct email")
        XCTAssertEqual(api.registrationRequests.first?.password, password, "Should pass correct password")
    }

    func test_register_onSuccessfulAPI_savesTokenAndReturnsSuccess() async {
        let (sut, api, tokenStorage, _) = makeSUT()
        let response = UserRegistrationResponse(userID: "123", token: "access-token", refreshToken: "refresh-token")
        api.completeRegistrationSuccessfully(with: response)

        let result = await sut.register(name: "John", email: "john@example.com", password: "password")

        let messages = await tokenStorage.messages
        XCTAssertEqual(messages.count, 1, "Should save token on successful registration")
        if case let .success(tokenAndUser) = result {
            XCTAssertEqual(tokenAndUser.token.accessToken, "access-token", "Should return correct access token")
            XCTAssertEqual(tokenAndUser.token.refreshToken, "refresh-token", "Should return correct refresh token")
            XCTAssertEqual(tokenAndUser.user.name, "John", "Should return correct user name")
            XCTAssertEqual(tokenAndUser.user.email, "john@example.com", "Should return correct user email")
        } else {
            XCTFail("Expected success result, got \(result)")
        }
    }

    func test_register_onAPIFailure_returnsFailureWithoutSavingToken() async {
        let (sut, api, tokenStorage, _) = makeSUT()
        let expectedError = UserRegistrationError.emailAlreadyInUse
        api.completeRegistration(with: expectedError)

        let result = await sut.register(name: "John", email: "john@example.com", password: "password")

        let messages = await tokenStorage.messages
        XCTAssertEqual(messages.count, 0, "Should not save token on API failure")
        if case let .failure(error) = result {
            XCTAssertEqual(error as? UserRegistrationError, expectedError, "Should return API error")
        } else {
            XCTFail("Expected failure result, got \(result)")
        }
    }

    func test_register_onTokenStorageFailure_returnsFailure() async {
        let (sut, api, tokenStorage, _) = makeSUT()
        let response = UserRegistrationResponse(userID: "123", token: "access-token", refreshToken: "refresh-token")
        api.completeRegistrationSuccessfully(with: response)
        let expectedError = TokenStorageError.encodingFailed(nil)
        await tokenStorage.completeSaveTokenBundle(withError: expectedError)

        let result = await sut.register(name: "John", email: "john@example.com", password: "password")

        if case let .failure(error) = result {
            XCTAssertEqual(error as? TokenStorageError, expectedError, "Should return token storage error")
        } else {
            XCTFail("Expected failure result, got \(result)")
        }
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: DefaultRegistrationService, api: AuthAPISpy, tokenStorage: TokenStorageSpy, offlineStore: OfflineRegistrationStoreSpy) {
        let api = AuthAPISpy()
        let tokenStorage = TokenStorageSpy()
        let offlineStore = OfflineRegistrationStoreSpy()
        let sut = DefaultRegistrationService(registrationAPI: api, tokenStorage: tokenStorage, offlineStore: offlineStore)

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(api, file: file, line: line)
        trackForMemoryLeaks(tokenStorage, file: file, line: line)
        trackForMemoryLeaks(offlineStore, file: file, line: line)

        return (sut, api, tokenStorage, offlineStore)
    }
}
