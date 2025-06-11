import EssentialFeed
import XCTest

final class GlobalLogoutIntegrationTests: XCTestCase {
    func test_performGlobalLogout_integrationFlow_clearsAllCredentialsAndStores() async throws {
        let (sut, stores) = makeIntegrationSUT()

        try await populateStoresWithTestData(stores)

        try await sut.performGlobalLogout()

        try await assertAllStoresAreCleared(stores)
    }

    func test_performGlobalLogout_whenTokenStorageFails_stopsExecutionAndPropagatesError() async {
        let (sut, stores) = makeIntegrationSUT()
        let expectedError = NSError(domain: "TokenStorageError", code: 500)
        stores.tokenStorage.deleteError = expectedError

        do {
            try await sut.performGlobalLogout()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as NSError, expectedError, "Should propagate token storage error")

            XCTAssertFalse(stores.offlineLoginStore.clearAllCalled, "Should not call offline login store when token storage fails")
            XCTAssertFalse(stores.offlineRegistrationStore.clearAllCalled, "Should not call offline registration store when token storage fails")
        }
    }

    func test_performGlobalLogout_whenMiddleStoreFails_propagatesErrorButPreviousStoresAreAlreadyCleared() async {
        let (sut, stores) = makeIntegrationSUT()
        let expectedError = NSError(domain: "OfflineRegistrationError", code: 503)
        stores.offlineRegistrationStore.clearAllError = expectedError

        do {
            try await sut.performGlobalLogout()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as NSError, expectedError, "Should propagate offline registration store error")

            XCTAssertEqual(stores.tokenStorage.deleteCallCount, 1, "Token storage should have been called before failure")
            XCTAssertTrue(stores.offlineLoginStore.clearAllCalled, "Offline login store should have been called before failure")
        }
    }

    func test_performGlobalLogout_withRealUserDefaults_clearsSessionKeysButPreservesOtherData() async throws {
        let testUserDefaults = UserDefaults(suiteName: "test_global_logout_integration")!
        let sessionUserDefaults = SessionUserDefaultsManager(userDefaults: testUserDefaults)
        let (sut, _) = makeIntegrationSUT(sessionUserDefaults: sessionUserDefaults)

        testUserDefaults.set("user123", forKey: "user_id")
        testUserDefaults.set("john_doe", forKey: "username")
        testUserDefaults.set("should_remain", forKey: "app_version")
        testUserDefaults.set("keep_this", forKey: "non_session_setting")

        try await sut.performGlobalLogout()

        XCTAssertNil(testUserDefaults.object(forKey: "user_id"), "Should clear session user_id")
        XCTAssertNil(testUserDefaults.object(forKey: "username"), "Should clear session username")
        XCTAssertEqual(testUserDefaults.string(forKey: "app_version"), "should_remain", "Should preserve non-session app_version")
        XCTAssertEqual(testUserDefaults.string(forKey: "non_session_setting"), "keep_this", "Should preserve non-session settings")

        testUserDefaults.removePersistentDomain(forName: "test_global_logout_integration")
    }

    func test_performGlobalLogout_concurrentCalls_handlesProperly() async throws {
        let (sut, _) = makeIntegrationSUT()

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await sut.performGlobalLogout() }
            group.addTask { try await sut.performGlobalLogout() }
            group.addTask { try await sut.performGlobalLogout() }

            try await group.waitForAll()
        }
    }

    private func makeIntegrationSUT(sessionUserDefaults: SessionUserDefaultsCleaning? = nil, file: StaticString = #filePath, line: UInt = #line) -> (sut: GlobalLogoutManager, stores: IntegrationStores) {
        let stores = IntegrationStores()
        let sessionUserDefaultsManager = sessionUserDefaults ?? stores.sessionUserDefaults

        let sut = GlobalLogoutManager(
            tokenStorage: stores.tokenStorage,
            offlineLoginStore: stores.offlineLoginStore,
            offlineRegistrationStore: stores.offlineRegistrationStore,
            failedLoginAttemptsStore: stores.failedLoginAttemptsStore,
            sessionUserDefaults: sessionUserDefaultsManager
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(stores.tokenStorage, file: file, line: line)
        trackForMemoryLeaks(stores.offlineLoginStore, file: file, line: line)
        trackForMemoryLeaks(stores.offlineRegistrationStore, file: file, line: line)
        trackForMemoryLeaks(stores.failedLoginAttemptsStore, file: file, line: line)
        trackForMemoryLeaks(stores.sessionUserDefaults, file: file, line: line)

        return (sut, stores)
    }

    private func populateStoresWithTestData(_ stores: IntegrationStores) async throws {
        let testToken = Token(accessToken: "test_token", expiry: Date().addingTimeInterval(3600), refreshToken: "refresh_token")
        try await stores.tokenStorage.save(tokenBundle: testToken)
        stores.offlineLoginStore.hasDataToReturn = true
        stores.offlineRegistrationStore.hasDataToReturn = true
        stores.failedLoginAttemptsStore.hasAttemptsToReturn = true
        stores.sessionUserDefaults.hasSessionDataToReturn = true
    }

    private func assertAllStoresAreCleared(_ stores: IntegrationStores) async throws {
        XCTAssertEqual(stores.tokenStorage.deleteCallCount, 1, "Should clear token storage")
        XCTAssertTrue(stores.offlineLoginStore.clearAllCalled, "Should clear offline login store")
        XCTAssertTrue(stores.offlineRegistrationStore.clearAllCalled, "Should clear offline registration store")
        XCTAssertTrue(stores.failedLoginAttemptsStore.clearAllCalled, "Should clear failed login attempts store")
        XCTAssertTrue(stores.sessionUserDefaults.clearSessionDataCalled, "Should clear session user defaults")

        let remainingToken = try await stores.tokenStorage.loadTokenBundle()
        XCTAssertNil(remainingToken, "Token should be deleted after global logout")
    }
}

private final class IntegrationStores {
    let tokenStorage = IntegrationTokenStorageSpy()
    let offlineLoginStore = IntegrationOfflineLoginStoreSpy()
    let offlineRegistrationStore = IntegrationOfflineRegistrationStoreSpy()
    let failedLoginAttemptsStore = IntegrationFailedLoginAttemptsStoreSpy()
    let sessionUserDefaults = IntegrationSessionUserDefaultsSpy()
}

private final class IntegrationTokenStorageSpy: TokenStorage {
    var deleteCallCount = 0
    var deleteError: Error?
    var saveError: Error?
    var storedToken: Token?

    func save(tokenBundle: Token) async throws {
        if let error = saveError {
            throw error
        }
        storedToken = tokenBundle
    }

    func loadTokenBundle() async throws -> Token? {
        storedToken
    }

    func deleteTokenBundle() async throws {
        deleteCallCount += 1
        if let error = deleteError {
            throw error
        }
        storedToken = nil
    }
}

private final class IntegrationOfflineLoginStoreSpy: OfflineLoginStoreCleaning {
    var clearAllCalled = false
    var clearAllError: Error?
    var hasDataToReturn = false

    func clearAll() async throws {
        clearAllCalled = true
        if let error = clearAllError {
            throw error
        }
    }
}

private final class IntegrationOfflineRegistrationStoreSpy: OfflineRegistrationStoreCleaning {
    var clearAllCalled = false
    var clearAllError: Error?
    var hasDataToReturn = false

    func clearAll() async throws {
        clearAllCalled = true
        if let error = clearAllError {
            throw error
        }
    }
}

private final class IntegrationFailedLoginAttemptsStoreSpy: FailedLoginAttemptsStoreCleaning {
    var clearAllCalled = false
    var clearAllError: Error?
    var hasAttemptsToReturn = false

    func clearAll() async throws {
        clearAllCalled = true
        if let error = clearAllError {
            throw error
        }
    }
}

private final class IntegrationSessionUserDefaultsSpy: SessionUserDefaultsCleaning {
    var clearSessionDataCalled = false
    var clearSessionDataError: Error?
    var hasSessionDataToReturn = false

    func clearSessionData() async throws {
        clearSessionDataCalled = true
        if let error = clearSessionDataError {
            throw error
        }
    }
}
