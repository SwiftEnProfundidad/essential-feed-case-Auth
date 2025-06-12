import EssentialFeed
import XCTest

final class RetryOfflineRegistrationsUseCaseTests: XCTestCase {
    func test_execute_whenNoOfflineRegistrations_doesNotAttemptApiCallAndCompletesSuccessfully() async {
        let (sut, spies) = makeSUT()
        spies.offlineStore.completeLoadAll(with: [])

        let results = await sut.execute()

        XCTAssertTrue(results.isEmpty, "Expected no results when no offline registrations")
        let offlineMessages = spies.offlineStore.messages
        XCTAssertEqual(offlineMessages, [.loadAll], "Expected only one call to loadAll")
        let authRequests = spies.authAPI.registrationRequests
        XCTAssertTrue(authRequests.isEmpty, "Expected no API registration calls")
        let tokenMessages = await spies.tokenStorage.messages
        XCTAssertTrue(tokenMessages.isEmpty, "Expected no token storage calls")
    }

    func test_execute_whenOneOfflineRegistrationExists_AndApiCallSucceeds_savesTokenAndDeletesFromOfflineStore() async {
        let (sut, spies) = makeSUT()

        let offlineData = UserRegistrationData(name: "Test User", email: "test@example.com", password: "ValidPassword123!")
        spies.offlineStore.completeLoadAll(with: [offlineData])

        let expectedApiResponse = UserRegistrationResponse(userID: "user-123", token: "new-auth-token", refreshToken: "new-refresh-token")
        spies.authAPI.completeRegistrationSuccessfully(with: expectedApiResponse)
        await spies.tokenStorage.completeSaveTokenBundleSuccessfully()
        spies.offlineStore.completeDeletionSuccessfully()

        let results = await sut.execute()

        XCTAssertEqual(results.count, 1, "Expected one result for one offline registration")
        guard let firstResult = results.first else {
            XCTFail("Results array should not be empty")
            return
        }

        switch firstResult {
        case .success:
            break
        case let .failure(error):
            XCTFail("Expected success, but got error: \(error)")
            return
        }

        let offlineMessages = spies.offlineStore.messages
        XCTAssertEqual(offlineMessages, [.loadAll, .delete(offlineData)], "Expected loadAll then delete from offlineStore")
        let authRequests = spies.authAPI.registrationRequests
        XCTAssertEqual(authRequests.count, 1, "Expected one call to authAPI.register")
        XCTAssertEqual(authRequests.first, offlineData, "AuthAPI was called with correct data")
        let tokenMessages = await spies.tokenStorage.messages
        XCTAssertEqual(tokenMessages.count, 1, "Expected one call to tokenStorage.save")

        if let firstTokenMessage = tokenMessages.first {
            if case let .save(tokenBundle: savedToken) = firstTokenMessage {
                XCTAssertEqual(savedToken.accessToken, expectedApiResponse.token, "Saved token access token mismatch")
                XCTAssertEqual(savedToken.refreshToken, expectedApiResponse.refreshToken, "Saved token refresh token mismatch")
            } else {
                XCTFail("Expected .save(tokenBundle:) message in tokenStorage, got \(firstTokenMessage)")
            }
        }
    }

    func test_execute_whenApiCallFails_keepsDataAndReturnsRegistrationFailed() async {
        let (sut, spies) = makeSUT()

        let offlineData = UserRegistrationData(name: "Bob", email: "bob@mail.com", password: "ValidPassword123!")
        spies.offlineStore.completeLoadAll(with: [offlineData])

        let expectedError = UserRegistrationError.emailAlreadyInUse
        spies.authAPI.completeRegistration(with: expectedError)

        let results = await sut.execute()

        XCTAssertEqual(results.count, 1)
        if case let .failure(.registrationFailed(receivedError))? = results.first {
            XCTAssertEqual(receivedError, expectedError)
        } else {
            XCTFail("Expected .registrationFailed error")
        }

        let offlineMessages = spies.offlineStore.messages
        XCTAssertEqual(offlineMessages, [.loadAll], "Should call loadAll only, without delete")
        let tokenMessages = await spies.tokenStorage.messages
        XCTAssertEqual(tokenMessages.count, 0, "Should not attempt to save token")
        let authRequests = spies.authAPI.registrationRequests
        XCTAssertEqual(authRequests, [offlineData], "API should receive the registration")
    }

    func test_execute_whenTokenStorageFails_keepsDataAndReturnsTokenStorageFailed() async {
        let (sut, spies) = makeSUT()

        let offlineData = UserRegistrationData(name: "Ana", email: "ana@mail.com", password: "ValidPassword!1")
        spies.offlineStore.completeLoadAll(with: [offlineData])

        let apiResponse = UserRegistrationResponse(userID: "user-ana", token: "token-ana", refreshToken: "refresh-ana")
        spies.authAPI.completeRegistrationSuccessfully(with: apiResponse)

        struct DummyError: Swift.Error {}
        await spies.tokenStorage.completeSaveTokenBundle(withError: DummyError())

        let results = await sut.execute()

        XCTAssertEqual(results.count, 1)
        if case let .failure(.tokenStorageFailed(receivedError)) = results.first {
            XCTAssertTrue(receivedError is DummyError, "Expected underlying DummyError, got \(receivedError)")
        } else {
            XCTFail("Expected .tokenStorageFailed with DummyError")
        }

        let offlineMessages = spies.offlineStore.messages
        XCTAssertEqual(offlineMessages, [.loadAll], "Solo loadAll, sin delete")
    }

    func test_execute_whenDeleteFails_keepsDataAndReturnsOfflineStoreDeleteFailed() async {
        let (sut, spies) = makeSUT()

        let offlineData = UserRegistrationData(name: "Eve", email: "eve@mail.com", password: "StrongPassw0rd!")
        spies.offlineStore.completeLoadAll(with: [offlineData])

        let apiResponse = UserRegistrationResponse(userID: "user-eve", token: "token-eve", refreshToken: "refresh-eve")
        spies.authAPI.completeRegistrationSuccessfully(with: apiResponse)
        await spies.tokenStorage.completeSaveTokenBundleSuccessfully()

        struct DummyError: Swift.Error {}
        spies.offlineStore.completeDeletion(with: DummyError())

        let results = await sut.execute()

        XCTAssertEqual(results.count, 1)

        if case let .failure(.offlineStoreDeleteFailed(receivedError)) = results.first {
            XCTAssertTrue(receivedError is DummyError, "Expected DummyError")
        } else {
            XCTFail("Expected .offlineStoreDeleteFailed")
        }

        let offlineMessages = spies.offlineStore.messages
        XCTAssertEqual(offlineMessages, [.loadAll, .delete(offlineData)])
        let tokenMessages = await spies.tokenStorage.messages
        XCTAssertEqual(tokenMessages.count, 1)
    }

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: RetryOfflineRegistrationsUseCase, spies: Spies) {
        let offlineStoreSpy = OfflineRegistrationStoreSpy()
        let authAPISpy = AuthAPISpy()
        let tokenStorageSpy = TokenStorageSpy()

        let sut = RetryOfflineRegistrationsUseCase(
            offlineStore: offlineStoreSpy,
            authAPI: authAPISpy,
            tokenStorage: tokenStorageSpy,
            userRegistration: authAPISpy
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(offlineStoreSpy, file: file, line: line)
        trackForMemoryLeaks(authAPISpy, file: file, line: line)
        trackForMemoryLeaks(tokenStorageSpy, file: file, line: line)

        return (sut, Spies(offlineStore: offlineStoreSpy, authAPI: authAPISpy, tokenStorage: tokenStorageSpy))
    }

    private struct Spies {
        let offlineStore: OfflineRegistrationStoreSpy
        let authAPI: AuthAPISpy
        let tokenStorage: TokenStorageSpy
    }
}
